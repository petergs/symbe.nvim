# symbe

A Neovim plugin geared towards interactive __deobfuscation workflows__: rename a symbol file-wide,
jump to a symbol, and highlight all instances of a symbol as you reverse engineer.

## Features

- **Rename symbol under cursor** — Prompts `Rename (oldname): `
  with an empty field so you type the new name, then rewrites every
  occurrence file-wide. 
- **Jump to symbol** — Telescope picker over every identifier in the buffer;
  fuzzy-filter and `<CR>` to jump.
- **Highlight all instances** — toggle a highlight over every occurrence of the
  symbol under the cursor (uses the `SymbeMatch` highlight group). While the
  highlight is active you get a lightweight "highlight mode": **`n`/`N`** cycle to
  the next/previous instance and **`<Esc>`** clears it. These keys are buffer-local
  and only override their defaults while highlighting is on.
- **Next / previous instance** — jump between occurrences of the symbol under the
  cursor
- **Help** — a floating window listing every command and its bound key.

## Install (lazy.nvim)

```lua
{
  "petergs/symbe.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" }
}
```

## Usage

| Default key   | Command           | Action                                   |
| ------------- | ----------------- | ---------------------------------------- |
| `<leader>sr`  | `:SymbeRename`    | Rename symbol under cursor, file-wide    |
| `<leader>sj`  | `:SymbeJump`      | Fuzzy-pick a symbol and jump to it       |
| `<leader>sh`  | `:SymbeHighlight` | Toggle highlight of all instances        |
| `<leader>sn`  | `:SymbeNext`      | Jump to next instance                    |
| `<leader>sN`  | `:SymbePrev`      | Jump to previous instance                |
| `<leader>s?`  | `:SymbeHelp`      | Show the shortcut list                   |

While a highlight is active: `n` next, `N` previous, `<Esc>` clear.

Highlight colour is the `SymbeMatch` group (links to `Search` by default);
override it with e.g. `vim.api.nvim_set_hl(0, "SymbeMatch", { bg = "#444466" })`.


## LLM Disclosure
This project is entirely written using Claude Opus 4.8 with minimal human oversight.
