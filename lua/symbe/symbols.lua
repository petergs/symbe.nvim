-- symbe.symbols: extract identifiers from a buffer.
-- Prefers treesitter (language-aware, skips strings/comments); falls back to a
-- word-regex scan for buffers with no available parser (minified/unknown blobs).

local M = {}

-- Try to get a treesitter tree for the buffer. Returns the root node or nil.
local function ts_root(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end
  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil
  end
  return trees[1]:root()
end

-- Heuristic: a node is an identifier if its type name contains "identifier".
-- Covers identifier / property_identifier / shorthand_property_identifier / etc.
local function is_identifier_type(t)
  return t:find("identifier", 1, true) ~= nil
end

-- Some grammars include surrounding whitespace in an identifier node's range
-- (e.g. tree-sitter-applescript emits " fileContents" for the token after
-- `write`). Identifiers never legitimately contain whitespace, so normalise to
-- the real token; otherwise renames/highlights would eat the adjacent space.
local function trim_token(text, scol, ecol)
  local lead = #(text:match("^%s*"))
  local trail = #(text:match("%s*$"))
  return text:sub(lead + 1, #text - trail), scol + lead, ecol - trail
end

local function add(symbols, name, row, col, end_col)
  local entry = symbols[name]
  if not entry then
    entry = { positions = {}, count = 0 }
    symbols[name] = entry
  end
  entry.count = entry.count + 1
  entry.positions[#entry.positions + 1] = { row, col, end_col }
end

-- Collect identifiers via treesitter by walking named nodes.
local function collect_treesitter(bufnr, root)
  local symbols = {}
  local function walk(node)
    for child in node:iter_children() do
      if child:named() then
        local t = child:type()
        if is_identifier_type(t) and child:child_count() == 0 then
          local srow, scol, erow, ecol = child:range()
          -- Identifiers never span lines; ignore the pathological case.
          if srow == erow then
            local text = vim.treesitter.get_node_text(child, bufnr)
            if text and text ~= "" then
              local name, s, e = trim_token(text, scol, ecol)
              if name ~= "" then
                add(symbols, name, srow, s, e)
              end
            end
          end
        else
          walk(child)
        end
      else
        walk(child)
      end
    end
  end
  walk(root)
  return symbols
end

-- Collect identifier-like tokens via a plain scan. Matches inside strings and
-- comments too -- this is the dumb fallback when no parser exists.
local function collect_regex(bufnr)
  local symbols = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, line in ipairs(lines) do
    local init = 1
    while true do
      local s, e = line:find("[%a_][%w_]*", init)
      if not s then
        break
      end
      -- Lua string indices are 1-based & byte cols; buffer API is 0-based.
      add(symbols, line:sub(s, e), row - 1, s - 1, e)
      init = e + 1
    end
  end
  return symbols
end

-- Returns the identifier table for a buffer:
--   { name = { positions = { {row, col, end_col}, ... }, count = n }, ... }
-- Positions are 0-based row and 0-based byte columns; end_col is exclusive.
function M.collect(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = ts_root(bufnr)
  if root then
    return collect_treesitter(bufnr, root), "treesitter"
  end
  return collect_regex(bufnr), "regex"
end

-- Returns the exact identifier under the cursor and its position, preferring
-- the treesitter node so we capture the real token boundaries.
-- Returns: name (string) or nil, position { row, col, end_col } or nil.
function M.symbol_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = ts_root(bufnr)
  if root then
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
    if ok and node and is_identifier_type(node:type()) then
      local srow, scol, erow, ecol = node:range()
      local text = vim.treesitter.get_node_text(node, bufnr)
      if text and text ~= "" and srow == erow then
        local name, s, e = trim_token(text, scol, ecol)
        if name ~= "" then
          return name, { srow, s, e }
        end
      end
    end
  end
  local word = vim.fn.expand("<cword>")
  if word == nil or word == "" then
    return nil, nil
  end
  return word, nil
end

return M
