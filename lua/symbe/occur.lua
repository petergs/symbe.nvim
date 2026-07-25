-- symbe.occur: highlight and navigate occurrences of the symbol under cursor.

local symbols = require("symbe.symbols")

local M = {}

local ns = vim.api.nvim_create_namespace("symbe_occur")

-- Which symbol is currently highlighted, per buffer: state[bufnr] = name.
local state = {}

-- While a symbol is highlighted we temporarily take over n / N / <Esc> in that
-- buffer so it feels like a "highlight mode". These are buffer-local and are
-- removed the moment the highlight is cleared, restoring normal behaviour.
local mode_maps = {
  n = function() M.goto_next() end,
  N = function() M.goto_prev() end,
  ["<Esc>"] = function() M.clear_highlight() end,
}

local function enable_mode_keys(bufnr)
  for lhs, fn in pairs(mode_maps) do
    vim.keymap.set("n", lhs, fn, {
      buffer = bufnr,
      nowait = true,
      desc = "symbe: highlight-mode " .. lhs,
    })
  end
end

local function disable_mode_keys(bufnr)
  for lhs in pairs(mode_maps) do
    pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
  end
end

-- Sorted (row, then col) occurrence positions {row, col, end_col} for `name`.
local function occurrences(bufnr, name)
  local tbl = symbols.collect(bufnr)
  local entry = tbl[name]
  if not entry then
    return {}
  end
  local positions = vim.deepcopy(entry.positions)
  table.sort(positions, function(a, b)
    if a[1] ~= b[1] then
      return a[1] < b[1]
    end
    return a[2] < b[2]
  end)
  return positions
end

function M.clear_highlight(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  disable_mode_keys(bufnr)
  state[bufnr] = nil
end

-- Toggle: highlight every occurrence of the symbol under the cursor. Running it
-- again on the same symbol clears; on a different symbol re-highlights.
function M.toggle_highlight()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = symbols.symbol_at_cursor(bufnr)
  if not name then
    vim.notify("symbe: no symbol under cursor", vim.log.levels.WARN)
    return
  end
  if state[bufnr] == name then
    M.clear_highlight(bufnr)
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local positions = occurrences(bufnr, name)
  for _, p in ipairs(positions) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, p[1], p[2], {
      end_row = p[1],
      end_col = p[3],
      hl_group = "SymbeMatch",
    })
  end
  state[bufnr] = name
  enable_mode_keys(bufnr)
  vim.notify(("symbe: %d occurrence%s of %s  (n/N to cycle, <Esc> to exit)")
    :format(#positions, #positions == 1 and "" or "s", name))
end

-- Jump to the next (dir=1) or previous (dir=-1) occurrence of the symbol under
-- the cursor, wrapping around the buffer.
local function goto_occurrence(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = symbols.symbol_at_cursor(bufnr)
  if not name then
    -- Fall back to whatever is currently highlighted, if anything.
    name = state[bufnr]
  end
  if not name then
    vim.notify("symbe: no symbol under cursor", vim.log.levels.WARN)
    return
  end

  local positions = occurrences(bufnr, name)
  if #positions == 0 then
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0) -- {row(1-based), col(0-based)}
  local crow, ccol = cur[1] - 1, cur[2]

  local target
  if dir > 0 then
    for _, p in ipairs(positions) do
      if p[1] > crow or (p[1] == crow and p[2] > ccol) then
        target = p
        break
      end
    end
    target = target or positions[1] -- wrap to first
  else
    for i = #positions, 1, -1 do
      local p = positions[i]
      if p[1] < crow or (p[1] == crow and p[2] < ccol) then
        target = p
        break
      end
    end
    target = target or positions[#positions] -- wrap to last
  end

  vim.api.nvim_win_set_cursor(0, { target[1] + 1, target[2] })
end

function M.goto_next()
  goto_occurrence(1)
end

function M.goto_prev()
  goto_occurrence(-1)
end

return M
