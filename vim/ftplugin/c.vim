""""""""""""""""""""""""""""""""""""""""""""""
"  Color
""""""""""""""""""""""""""""""""""""""""""""""
hi Type	cterm=NONE	ctermfg=yellow	ctermbg=NONE

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
