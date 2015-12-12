""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi def LeadingTab term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f

match LeadingTab /^\t\+/
match BadWhitespace /\s\+$/

""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""
nnoremap <F5> :wa<CR>:make %:r<CR>
setlocal expandtab

" purge trailing space
autocmd BufWritePre *.c :call StripTrailingWhitespaces()
autocmd BufWritePre *.cpp :call StripTrailingWhitespaces()
autocmd BufWritePre *.h :call StripTrailingWhitespaces()
autocmd BufWritePre *.hpp :call StripTrailingWhitespaces()
