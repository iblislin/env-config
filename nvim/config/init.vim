" nvim entry point.  Linked to ~/.config/nvim by init.sh.
"
" The bulk of the configuration is the vimrc shared with vim; only the parts vim
" cannot run live here.  Today that means the LSP client: yegappan/lsp is Vim9
" script, so nvim uses its own built-in vim.lsp instead.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vim/vimrc

lua require('lsp_common')
lua require('python_lsp')
lua require('ts_lsp')
lua require('finder')
lua require('markdown')
lua require('gitlab_review')

" gf and <C-w>gf open in a tab, reusing one already showing the file -- the same
" select_tab_drop rule finder.lua uses.  Global, not on LspAttach: a path under
" the cursor is a path whether or not a language server is running.
"
" gF is left alone.  It jumps to file AND line for `name:123`, which this does
" not parse, so shadowing it would be a quiet downgrade.  A count before gf is
" lost the same way; <C-w>gf is included because it already meant "in a tab".
lua << EOF
local goto_ = require('goto')
local function gf_tab()
  local file = goto_.file_under_cursor()
  if file then
    goto_.tab_drop(file)
  else
    vim.notify('gf: no file under the cursor', vim.log.levels.WARN)
  end
end
vim.keymap.set('n', 'gf', gf_tab, { silent = true, desc = 'go to file (tab)' })
vim.keymap.set('n', '<C-w>gf', gf_tab, { silent = true, desc = 'go to file (tab)' })
EOF
