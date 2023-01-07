setlocal ts=2 sw=2

" purge trailing space
autocmd BufWritePre *.yaml :call StripTrailingWhitespaces()
autocmd BufWritePre *.yml :call StripTrailingWhitespaces()
