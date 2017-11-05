autocmd BufWritePre *.rst :call StripTrailingWhitespaces()

setlocal spell

" vim-table-mode
let g:table_mode_corner='|'
let g:table_mode_corner_corner='|'
let g:table_mode_header_fillchar='-'
