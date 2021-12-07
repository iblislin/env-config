""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingTab term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
hi Function           cterm=NONE ctermfg=11 ctermbg=NONE
hi pythonFunctionCall cterm=NONE ctermfg=81 ctermbg=NONE

match LeadingTab /^\t\+/
match BadWhitespace /\s\+$/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab

" nnoremap <buffer> <F5> :w<CR>:pyfile %<CR>
" nnoremap <buffer> <leader>e :w<CR>:!${VIRTUAL_ENV}/bin/python hier_triangle.py %<CR>
imap <buffer> <F5> <ESC><F7>

if !has('nvim')  " vim only
    nnoremap <expr> <CR> SmartNewLine() ? "i<CR><Esc>" : "i^<C-D><CR><Esc>"
endif

" purge trailing space
autocmd BufWritePre *.py :call StripTrailingWhitespaces()

""""""""""""""""""""""""""""""""""""""""""""""
" SuperTab
""""""""""""""""""""""""""""""""""""""""""""""
let g:SuperTabDefaultCompletionType = "<c-x><c-o>"

""""""""""""""""""""""""""""""""""""""""""""""
" vim-slime
""""""""""""""""""""""""""""""""""""""""""""""
let g:slime_vimterminal_cmd = "python"
