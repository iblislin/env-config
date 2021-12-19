""""""""""""""""""""""""""""""""""""""""""""""
"  General
""""""""""""""""""""""""""""""""""""""""""""""

setlocal dictionary+=~/.vim/dict/latex
setlocal complete+=k
setlocal iskeyword+=\

setlocal ts=2
setlocal shiftwidth=2

setlocal conceallevel=0
let g:tex_conceal=""

" purge trailing space
autocmd BufWritePre *.latex :call StripTrailingWhitespaces()
autocmd BufWritePre *.tex :call StripTrailingWhitespaces()
