-- symbe.rename: rename the symbol under the cursor file-wide in one undo step.

local symbols = require("symbe.symbols")

local M = {}

-- Rebuild buffer lines, replacing the exact byte ranges in `positions` with
-- `new`. `positions` is a list of {row, col, end_col} (0-based, end exclusive).
-- Applying per line, right-to-left, keeps earlier column offsets valid.
local function apply_positions(bufnr, positions, new)
  local by_row = {}
  for _, p in ipairs(positions) do
    local row = p[1]
    by_row[row] = by_row[row] or {}
    table.insert(by_row[row], p)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, ranges in pairs(by_row) do
    table.sort(ranges, function(a, b)
      return a[2] > b[2] -- descending start col
    end)
    local line = lines[row + 1]
    for _, r in ipairs(ranges) do
      line = line:sub(1, r[2]) .. new .. line:sub(r[3] + 1)
    end
    lines[row + 1] = line
  end
  -- Single set_lines => single undo step.
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

-- Regex fallback: build word-boundary positions ourselves so strings/comments
-- are treated the same as code (we have no parser to tell them apart anyway).
local function word_positions(bufnr, name)
  local positions = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local esc = name:gsub("(%W)", "%%%1") -- escape Lua pattern magic chars
  local pat = "%f[%w_]" .. esc .. "%f[^%w_]" -- frontier = word boundaries
  for row, line in ipairs(lines) do
    local init = 1
    while true do
      local s, e = line:find(pat, init)
      if not s then
        break
      end
      positions[#positions + 1] = { row - 1, s - 1, e }
      init = e + 1
    end
  end
  return positions
end

function M.rename_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local old = symbols.symbol_at_cursor(bufnr)
  if not old then
    vim.notify("symbe: no symbol under cursor", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = ("Rename (%s): "):format(old) }, function(new)
    if not new or new == "" or new == old then
      return
    end

    local table_, source = symbols.collect(bufnr)
    local positions
    if source == "treesitter" and table_[old] then
      positions = table_[old].positions
    else
      -- No parser, or the name only appears inside strings/comments: fall back
      -- to a word-boundary scan so a rename still does something sensible.
      positions = word_positions(bufnr, old)
    end

    if #positions == 0 then
      vim.notify("symbe: no occurrences of " .. old, vim.log.levels.WARN)
      return
    end

    apply_positions(bufnr, positions, new)
    vim.notify(
      ("symbe: renamed %d occurrence%s of %s -> %s")
        :format(#positions, #positions == 1 and "" or "s", old, new)
    )
  end)
end

return M
