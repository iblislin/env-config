hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f

match BadWhitespace /\s\+$/

setlocal foldmethod=indent
setlocal expandtab
setlocal tabstop=2
setlocal softtabstop=2
setlocal shiftwidth=2

autocmd BufWritePre *.ts :call StripTrailingWhitespaces()
