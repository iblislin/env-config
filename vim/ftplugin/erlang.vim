""""""""""""""""""""""""""""""""""""""""
" SuperTab
""""""""""""""""""""""""""""""""""""""""
let g:SuperTabDefaultCompletionType = "<c-x><c-o>"

""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi Identifier       cterm=NONE      ctermfg=11     ctermbg=NONE
hi Type             cterm=NONE      ctermfg=13     ctermbg=NONE
hi PreProc          cterm=NONE      ctermfg=3     ctermbg=NONE

hi def LeadingTab term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f

match LeadingTab /^\t\+/
match BadWhitespace /\s\+$/


" purge trailing space
autocmd BufWritePre *.erl :call StripTrailingWhitespaces()
