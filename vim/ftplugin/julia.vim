setlocal ts=2 sw=2 commentstring=#%s

nnoremap <leader>j :setlocal ts=2 sw=2 commentstring=#%s<cr>

autocmd BufWritePre *.jl :call StripTrailingWhitespaces()
