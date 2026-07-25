-- symbe.picker: telescope picker over the buffer's identifiers; jump on select.

local symbols = require("symbe.symbols")

local M = {}

function M.symbols()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("symbe: telescope not available", vim.log.levels.ERROR)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local table_ = symbols.collect(bufnr)

  -- Flatten to a list of unique names, each carrying its first occurrence.
  local items = {}
  for name, entry in pairs(table_) do
    local first = entry.positions[1]
    items[#items + 1] = { name = name, count = entry.count, pos = first }
  end
  table.sort(items, function(a, b)
    return a.name < b.name
  end)

  pickers
    .new({}, {
      prompt_title = "Symbols",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item,
            display = ("%s  (%d)"):format(item.name, item.count),
            ordinal = item.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value.pos then
            local pos = selection.value.pos -- {row, col, end_col}, 0-based
            vim.api.nvim_win_set_cursor(winid, { pos[1] + 1, pos[2] })
          end
        end)
        return true
      end,
    })
    :find()
end

return M
