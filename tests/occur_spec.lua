local occur = require("symbe.occur")

local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "text"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

describe("symbe.occur", function()
  it("jumps to the next occurrence and wraps around", function()
    make_buf({ "foo bar", "baz foo", "foo end" }) -- foo at (0,0),(1,4),(2,0)

    vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on first foo
    occur.goto_next()
    assert.same({ 2, 4 }, vim.api.nvim_win_get_cursor(0))

    vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- on last foo
    occur.goto_next() -- wraps to first
    assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("jumps to the previous occurrence and wraps around", function()
    make_buf({ "foo bar", "baz foo", "foo end" })

    vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- on last foo
    occur.goto_prev()
    assert.same({ 2, 4 }, vim.api.nvim_win_get_cursor(0))

    vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on first foo
    occur.goto_prev() -- wraps to last
    assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  local function has_buf_map(bufnr, lhs)
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
      if m.lhs == lhs then
        return true
      end
    end
    return false
  end

  it("toggles extmark highlights and highlight-mode keys", function()
    local bufnr = make_buf({ "foo bar", "baz foo", "foo end" })
    local ns = vim.api.nvim_create_namespace("symbe_occur")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    occur.toggle_highlight()
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    assert.equals(3, #marks)
    -- n / N / <Esc> are taken over while highlighting is active.
    assert.is_true(has_buf_map(bufnr, "n"))
    assert.is_true(has_buf_map(bufnr, "N"))

    occur.toggle_highlight() -- same symbol -> clears
    marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
    assert.equals(0, #marks)
    assert.is_false(has_buf_map(bufnr, "n")) -- keys restored
    assert.is_false(has_buf_map(bufnr, "N"))
  end)

  it("clear_highlight (as <Esc> does) removes highlight-mode keys", function()
    local bufnr = make_buf({ "foo bar", "baz foo" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    occur.toggle_highlight()
    assert.is_true(has_buf_map(bufnr, "n"))
    occur.clear_highlight(bufnr)
    assert.is_false(has_buf_map(bufnr, "n"))
  end)
end)
