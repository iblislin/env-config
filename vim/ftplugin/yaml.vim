setlocal ts=2 sw=2
setlocal expandtab

" purge trailing space
autocmd BufWritePre *.yaml :call StripTrailingWhitespaces()
autocmd BufWritePre *.yml :call StripTrailingWhitespaces()
