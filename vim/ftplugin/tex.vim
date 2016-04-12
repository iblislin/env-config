""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""

setlocal dictionary+=~/.vim/dict/latex
setlocal complete+=k
setlocal iskeyword+=\

" purge trailing space
autocmd BufWritePre *.latex :call StripTrailingWhitespaces()
autocmd BufWritePre *.tex :call StripTrailingWhitespaces()
