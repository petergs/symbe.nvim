-- Minimal init for headless plenary tests.
-- Puts this plugin and plenary (+ treesitter, if present) on the runtimepath.

local function add_pack(name)
  local candidates = {
    vim.fn.stdpath("data") .. "/lazy/" .. name,
    vim.fn.expand("~/.local/share/nvim/lazy/" .. name),
    vim.fn.stdpath("data") .. "/site/pack/packer/start/" .. name,
  }
  for _, p in ipairs(candidates) do
    if vim.fn.isdirectory(p) == 1 then
      vim.opt.runtimepath:append(p)
      return true
    end
  end
  return false
end

-- This plugin itself.
local here = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
vim.opt.runtimepath:append(here)

add_pack("plenary.nvim")
add_pack("nvim-treesitter")

vim.cmd("runtime plugin/plenary.vim")
