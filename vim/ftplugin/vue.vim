hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
match BadWhitespace /\s\+$/

autocmd BufWritePre *.vue :call StripTrailingWhitespaces()
