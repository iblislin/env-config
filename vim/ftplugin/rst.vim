let rst_syntax_code_list = ['python', 'sh', 'erlang']

setlocal spell

" purge trailing space
autocmd BufWritePre *.rst :call StripTrailingWhitespaces()

" vim-table-mode
let g:table_mode_corner_corner='+'
let g:table_mode_header_fillchar='='
