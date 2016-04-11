" purge trailing space
autocmd BufWritePre *.latex :call StripTrailingWhitespaces()
autocmd BufWritePre *.tex :call StripTrailingWhitespaces()
