""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi Identifier       cterm=NONE      ctermfg=11  ctermbg=NONE
hi Type             cterm=NONE      ctermfg=13     ctermbg=NONE
hi def LeadingTab term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f

match LeadingTab /^\t\+/
match BadWhitespace /\s\+$/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab

" nnoremap <buffer> <F5> :w<CR>:pyfile %<CR>
nnoremap <buffer> <leader>e :w<CR>:!${VIRTUAL_ENV}/bin/python hier_triangle.py %<CR>
imap <buffer> <F5> <ESC><F5>

nnoremap <expr> <CR> SmartNewLine() ? "i<CR><Esc>" : "i^<C-D><CR><Esc>"

" purge trailing space
autocmd BufWritePre *.py :call StripTrailingWhitespaces()

""""""""""""""""""""""""""""""""""""""""""""""
" SuperTab
""""""""""""""""""""""""""""""""""""""""""""""
let g:SuperTabDefaultCompletionType = "<c-x><c-o>"
