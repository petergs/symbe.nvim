-- symbe: fast symbol rename / jump / annotate for deobfuscating scripts.

local M = {}

local defaults = {
  -- Default keymaps; set any to false to disable, or override the lhs.
  keys = {
    rename = "<leader>sr",
    jump = "<leader>sj",
    highlight = "<leader>sh",
    next = "<leader>sn",
    prev = "<leader>sN",
    help = "<leader>s?",
  },
  -- When true, enable live :substitute preview (nvim's inccommand).
  inccommand = false,
}

M.config = defaults

-- Each action: config key -> { fn, command, desc }. Drives keymaps, user
-- commands, and the help window from a single source of truth.
local actions = {
  {
    key = "rename",
    cmd = "SymbeRename",
    desc = "Rename symbol under cursor, file-wide",
    fn = function() require("symbe.rename").rename_under_cursor() end,
  },
  {
    key = "jump",
    cmd = "SymbeJump",
    desc = "Fuzzy-pick a symbol and jump to it",
    fn = function() require("symbe.picker").symbols() end,
  },
  {
    key = "highlight",
    cmd = "SymbeHighlight",
    desc = "Toggle highlight of all instances of symbol",
    fn = function() require("symbe.occur").toggle_highlight() end,
  },
  {
    key = "next",
    cmd = "SymbeNext",
    desc = "Jump to next instance of symbol",
    fn = function() require("symbe.occur").goto_next() end,
  },
  {
    key = "prev",
    cmd = "SymbePrev",
    desc = "Jump to previous instance of symbol",
    fn = function() require("symbe.occur").goto_prev() end,
  },
  {
    key = "help",
    cmd = "SymbeHelp",
    desc = "Show this shortcut list",
    fn = function() M.help() end,
  },
}

-- Show the available commands and their bound keys in a floating window.
function M.help()
  local keys = M.config.keys
  local lines = { " symbe — shortcuts", "" }
  local rows = {}
  local width = 0
  for _, a in ipairs(actions) do
    local lhs = keys[a.key]
    local key_col = lhs and lhs or "(unbound)"
    rows[#rows + 1] = { key_col, ":" .. a.cmd, a.desc }
    width = math.max(width, #key_col)
  end
  for _, r in ipairs(rows) do
    lines[#lines + 1] = ("  %-" .. (width + 2) .. "s%-16s%s"):format(r[1], r[2], r[3])
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = " press q or <Esc> to close"

  local win_width = 0
  for _, l in ipairs(lines) do
    win_width = math.max(win_width, #l)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width + 2,
    height = #lines,
    row = (vim.o.lines - #lines) / 2,
    col = (vim.o.columns - win_width) / 2,
    style = "minimal",
    border = "rounded",
    title = " symbe ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })
  end
end

-- The SymbeMatch highlight survives colorscheme changes (which reset hlgroups).
local function set_hl()
  vim.api.nvim_set_hl(0, "SymbeMatch", { link = "Search", default = true })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("SymbeHighlight", { clear = true }),
    callback = set_hl,
  })

  for _, a in ipairs(actions) do
    vim.api.nvim_create_user_command(a.cmd, a.fn, {})
    local lhs = M.config.keys[a.key]
    if lhs then
      vim.keymap.set("n", lhs, a.fn, { desc = "symbe: " .. a.desc })
    end
  end

  if M.config.inccommand then
    vim.o.inccommand = "split"
  end
end

return M
