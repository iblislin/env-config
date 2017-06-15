""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""

setlocal dictionary+=~/.vim/dict/latex
setlocal complete+=k
setlocal iskeyword+=\

setlocal ts=2
setlocal shiftwidth=2

" purge trailing space
autocmd BufWritePre *.latex :call StripTrailingWhitespaces()
autocmd BufWritePre *.tex :call StripTrailingWhitespaces()
