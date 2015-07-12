""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingTab term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
match LeadingTab /^\t\+/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab

nnoremap <buffer> <F5> :w<CR>:pyfile %<CR>
imap <buffer> <F5> <ESC><F5>

nnoremap <expr> <CR> SmartNewLine() ? "i<CR><Esc>" : "i^<C-D><CR><Esc>"

""""""""""""""""""""""""""""""""""""""""
" SuperTab
""""""""""""""""""""""""""""""""""""""""
let g:SuperTabDefaultCompletionType = "<c-x><c-o>"
