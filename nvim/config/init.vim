" nvim entry point.  Linked to ~/.config/nvim by init.sh.
"
" The bulk of the configuration is the vimrc shared with vim; only the parts vim
" cannot run live here.  Today that means the LSP client: yegappan/lsp is Vim9
" script, so nvim uses its own built-in vim.lsp instead.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vim/vimrc

lua require('python_lsp')
