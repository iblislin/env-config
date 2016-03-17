let rst_syntax_code_list = ['python', 'sh', 'erlang']

" purge trailing space
autocmd BufWritePre *.rst :call StripTrailingWhitespaces()
