setlocal ts=2 sw=2 commentstring=#%s

nnoremap <leader>j :setlocal ts=2 sw=2 commentstring=#%s<cr>

autocmd BufWritePre *.jl :call StripTrailingWhitespaces()

hi Statement        cterm=NONE      ctermfg=9        ctermbg=NONE
