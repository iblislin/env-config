-- Fuzzy finder, bound to <leader>f like VS Code's Ctrl-P.
--
-- nvim-only on purpose: telescope is lua, and nvim is where the coding happens.
-- vim keeps no equivalent for now, so do not expect ,f to work there.
--
-- find_files shells out to `fd` when it exists and plain `find` otherwise; `fd`
-- is not installed here but ripgrep is, and `rg --files` honours .gitignore the
-- same way, so point it there rather than at find.
local ok, telescope = pcall(require, 'telescope')
if not ok then
  return
end

local actions = require('telescope.actions')

telescope.setup({
  defaults = {
    layout_strategy = 'flex',
    sorting_strategy = 'ascending',
    layout_config = { prompt_position = 'top' },
    -- One tab per file is the working model here -- `vi` is `nvim -p`, so files
    -- arrive as tabs and the fern drawer is per-tab.  select_tab_drop rather
    -- than select_tab: it jumps to the tab already showing the file instead of
    -- opening a second one, which is what stops <CR>-happy searching from
    -- growing three tabs on the same buffer.
    --
    -- Set on `defaults`, so <leader>b and <leader>/ behave the same way; the
    -- splits stay on <C-v>/<C-x> for when a side-by-side really is wanted.
    mappings = {
      i = { ['<CR>'] = actions.select_tab_drop, ['<C-t>'] = actions.select_tab_drop },
      n = { ['<CR>'] = actions.select_tab_drop, ['<C-t>'] = actions.select_tab_drop },
    },
  },
  pickers = {
    find_files = {
      find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*' },
    },
  },
})

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>f', builtin.find_files, { desc = 'find files' })
vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'find buffers' })
vim.keymap.set('n', '<leader>/', builtin.live_grep, { desc = 'grep in project' })
