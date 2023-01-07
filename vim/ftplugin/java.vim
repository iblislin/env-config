" purge trailing space
autocmd BufWritePre *.java :call StripTrailingWhitespaces()
