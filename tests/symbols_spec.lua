local symbols = require("symbe.symbols")

local function make_buf(ft, lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = ft
  return bufnr
end

describe("symbe.symbols", function()
  it("extracts identifiers via treesitter and skips string contents", function()
    local bufnr = make_buf("javascript", {
      "var alpha = 1;",
      'var beta = "alpha";', -- 'alpha' here is inside a string literal
    })
    local tbl, source = symbols.collect(bufnr)
    -- If the JS parser isn't installed this test is not meaningful; guard it.
    if source ~= "treesitter" then
      pending("javascript treesitter parser not installed")
      return
    end
    assert.equals(1, tbl["alpha"].count) -- only the declaration, not the string
    assert.equals(1, tbl["beta"].count)
  end)

  it("trims whitespace a grammar wrongly includes in an identifier node", function()
    -- tree-sitter-applescript emits the token after `write` as " fileContents"
    -- (leading space inside the identifier node). Regression for that.
    local bufnr = make_buf("applescript", {
      "write fileContents to fileWriteHandle starting at eof",
    })
    local tbl, source = symbols.collect(bufnr)
    if source ~= "treesitter" then
      pending("applescript treesitter parser not installed")
      return
    end
    assert.is_not_nil(tbl["fileContents"]) -- keyed by the trimmed name
    assert.is_nil(tbl[" fileContents"]) -- not the space-prefixed variant
    local line = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
    local p = tbl["fileContents"].positions[1]
    assert.equals("fileContents", line:sub(p[2] + 1, p[3])) -- range excludes space
  end)

  it("falls back to a regex scan when no parser exists", function()
    local bufnr = make_buf("text", { "foo bar foo", "baz" })
    local tbl, source = symbols.collect(bufnr)
    assert.equals("regex", source)
    assert.equals(2, tbl["foo"].count)
    assert.equals(1, tbl["bar"].count)
    assert.equals(1, tbl["baz"].count)
  end)
end)
