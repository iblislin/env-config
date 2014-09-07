""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingSpaces term=reverse ctermfg=15 ctermbg=241 gui=reverse guifg=#dc322f
match LeadingSpaces /^\ \+/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
setlocal foldmethod=indent
setlocal expandtab
nnoremap <buffer> <F5> :w<CR>:exec '!python' shellescape(@%, 1)<CR>
imap <buffer> <F5> <ESC><F5>
