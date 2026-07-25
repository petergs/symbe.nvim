local rename = require("symbe.rename")

-- Reach into the module's word_positions/apply behaviour through the public
-- entry point by stubbing vim.ui.input. We test on a no-parser buffer so the
-- word-boundary regex path is exercised deterministically.
local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "text"
  vim.api.nvim_set_current_buf(bufnr)
  -- Break the undo sequence so the setup edit and the rename are separate undo
  -- blocks (assigning &undolevels forces an undo boundary).
  vim.bo[bufnr].undolevels = vim.bo[bufnr].undolevels
  return bufnr
end

local function do_rename(new)
  local orig = vim.ui.input
  vim.ui.input = function(_, cb)
    cb(new)
  end
  -- Place cursor on the first token of line 1.
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  rename.rename_under_cursor()
  vim.ui.input = orig
end

describe("symbe.rename", function()
  it("renames whole-word occurrences only, in one undo step", function()
    local bufnr = make_buf({ "a1b2 = a1b2 + a1b2c", "x = a1b2" })
    do_rename("token")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    -- a1b2 replaced 3x; a1b2c (substring) untouched.
    assert.equals("token = token + a1b2c", lines[1])
    assert.equals("x = token", lines[2])

    -- A single undo reverts the entire rename.
    vim.cmd("silent undo")
    local reverted = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.equals("a1b2 = a1b2 + a1b2c", reverted[1])
    assert.equals("x = a1b2", reverted[2])
  end)
end)
