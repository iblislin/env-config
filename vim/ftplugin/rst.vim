" reStructuredText filetype plugin file
" Language: reStructuredText documentation format
" Maintainer: Marshall Ward <marshall.ward@gmail.com>
" Original Maintainer: Nikolai Weibull <now@bitwi.se>
" Website: https://github.com/marshallward/vim-restructuredtext
" Latest Revision: 2018-01-07

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< et< fo<"

setlocal comments=fb:.. commentstring=..\ %s expandtab
setlocal formatoptions+=tcroql

" reStructuredText standard recommends that tabs be expanded to 8 spaces
" The choice of 3-space indentation is to provide slightly better support for
" directives (..) and ordered lists (1.), although it can cause problems for
" many other cases.
"
" More sophisticated indentation rules should be revisted in the future.

if !exists("g:rst_style") || g:rst_style != 0
    setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4
endif

if has('patch-7.3.867')  " Introduced the TextChanged event.
  setlocal foldmethod=expr
  setlocal foldexpr=RstFold#GetRstFold()
  setlocal foldtext=RstFold#GetRstFoldText()
  augroup RstFold
    autocmd TextChanged,InsertLeave <buffer> unlet! b:RstFoldCache
  augroup END
endif

let &cpo = s:cpo_save
unlet s:cpo_save


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"  patch
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let rst_syntax_code_list = ['python', 'sh', 'erlang']

setlocal spell

" purge trailing space
autocmd BufWritePre *.rst :call StripTrailingWhitespaces()

" vim-table-mode
let g:table_mode_corner_corner='+'
let g:table_mode_header_fillchar='='
