" Vim color file
" Name:       iblis
" Maintainer: Iblis Lin
" Version:    0.20

set background=dark
hi clear
if exists("syntax_on")
   syntax reset
endif

let colors_name = "iblis"

if has("gui_running")
    hi Normal         gui=NONE   guifg=#cfbfad   guibg=#000000

    hi IncSearch      gui=BOLD   guifg=#303030   guibg=#cd8b60
    hi Search         gui=NONE   guifg=#303030   guibg=#cd8b60
    hi ErrorMsg       gui=BOLD   guifg=#ffffff   guibg=#ce8e4e
    hi WarningMsg     gui=BOLD   guifg=#ffffff   guibg=#ce8e4e
    hi ModeMsg        gui=BOLD   guifg=#7e7eae   guibg=NONE
    hi MoreMsg        gui=BOLD   guifg=#7e7eae   guibg=NONE
    hi Question       gui=BOLD   guifg=#ffcd00   guibg=NONE

    hi StatusLine     gui=BOLD   guifg=#b9b9b9   guibg=#3e3e5e
    hi User1          gui=BOLD   guifg=#00ff8b   guibg=#3e3e5e
    hi User2          gui=BOLD   guifg=#7070a0   guibg=#3e3e5e
    hi StatusLineNC   gui=NONE   guifg=#b9b9b9   guibg=#3e3e5e
    hi VertSplit      gui=NONE   guifg=#b9b9b9   guibg=#3e3e5e

    hi WildMenu       gui=BOLD   guifg=#eeeeee   guibg=#6e6eaf

    hi MBENormal                 guifg=#cfbfad   guibg=#2e2e3f
    hi MBEChanged                guifg=#eeeeee   guibg=#2e2e3f
    hi MBEVisibleNormal          guifg=#cfcfcd   guibg=#4e4e8f
    hi MBEVisibleChanged         guifg=#eeeeee   guibg=#4e4e8f

    hi DiffText       gui=NONE   guifg=#ffffcd   guibg=#4a2a4a
    hi DiffChange     gui=NONE   guifg=#ffffcd   guibg=#306b8f
    hi DiffDelete     gui=NONE   guifg=#ffffcd   guibg=#6d3030
    hi DiffAdd        gui=NONE   guifg=#ffffcd   guibg=#306d30

    hi Cursor         gui=NONE   guifg=#404040   guibg=#8b8bff
    hi lCursor        gui=NONE   guifg=#404040   guibg=#8fff8b
    hi CursorIM       gui=NONE   guifg=#404040   guibg=#8b8bff

    hi Folded         gui=NONE   guifg=#cfcfcd   guibg=#4b208f
    hi FoldColumn     gui=NONE   guifg=#8b8bcd   guibg=#2e2e2e

    hi Directory      gui=NONE   guifg=#00ff8b   guibg=NONE
    hi LineNr         gui=NONE   guifg=#8b8bcd   guibg=#2e2e2e
    hi NonText        gui=BOLD   guifg=#8b8bcd   guibg=NONE
    hi SpecialKey     gui=BOLD   guifg=#ab60ed   guibg=NONE
    hi Title          gui=BOLD   guifg=#af4f4b   guibg=NONE
    hi Visual         gui=NONE   guifg=#eeeeee   guibg=#4e4e8f

    hi Comment        gui=NONE   guifg=#cd8b00   guibg=NONE
    hi Constant       gui=NONE   guifg=#ffcd8b   guibg=NONE
    hi String         gui=NONE   guifg=#ffcd8b   guibg=#404040
    hi Error          gui=NONE   guifg=#ffffff   guibg=#6e2e2e
    hi Identifier     gui=NONE   guifg=#ff8bff   guibg=NONE
    hi Ignore         gui=NONE
    hi Number         gui=NONE   guifg=#f0ad6d   guibg=NONE
    hi PreProc        gui=NONE   guifg=#409090   guibg=NONE
    hi Special        gui=NONE   guifg=#c080d0   guibg=NONE
    hi SpecialChar    gui=NONE   guifg=#c080d0   guibg=#404040
    hi Statement      gui=NONE   guifg=#808bed   guibg=NONE
    hi Todo           gui=BOLD   guifg=#303030   guibg=#d0a060
    hi Type           gui=NONE   guifg=#ff8bff   guibg=NONE
    hi Underlined     gui=BOLD   guifg=#df9f2d   guibg=NONE
    hi TaglistTagName gui=BOLD   guifg=#808bed   guibg=NONE

    hi perlSpecialMatch   gui=NONE guifg=#c080d0   guibg=#404040
    hi perlSpecialString  gui=NONE guifg=#c080d0   guibg=#404040

    hi cSpecialCharacter  gui=NONE guifg=#c080d0   guibg=#404040
    hi cFormat            gui=NONE guifg=#c080d0   guibg=#404040

    hi doxygenBrief                 gui=NONE guifg=#fdab60   guibg=NONE
    hi doxygenParam                 gui=NONE guifg=#fdd090   guibg=NONE
    hi doxygenPrev                  gui=NONE guifg=#fdd090   guibg=NONE
    hi doxygenSmallSpecial          gui=NONE guifg=#fdd090   guibg=NONE
    hi doxygenSpecial               gui=NONE guifg=#fdd090   guibg=NONE
    hi doxygenComment               gui=NONE guifg=#ad7b20   guibg=NONE
    hi doxygenSpecial               gui=NONE guifg=#fdab60   guibg=NONE
    hi doxygenSpecialMultilineDesc  gui=NONE guifg=#ad600b   guibg=NONE
    hi doxygenSpecialOnelineDesc    gui=NONE guifg=#ad600b   guibg=NONE

    if v:version >= 700
        hi Pmenu          gui=NONE   guifg=#eeeeee   guibg=#4e4e8f
        hi PmenuSel       gui=BOLD   guifg=#eeeeee   guibg=#2e2e3f
        hi PmenuSbar      gui=BOLD   guifg=#eeeeee   guibg=#6e6eaf
        hi PmenuThumb     gui=BOLD   guifg=#eeeeee   guibg=#6e6eaf

        hi SpellBad     gui=undercurl guisp=#cc6666
        hi SpellRare    gui=undercurl guisp=#cc66cc
        hi SpellLocal   gui=undercurl guisp=#cccc66
        hi SpellCap     gui=undercurl guisp=#66cccc

        hi MatchParen   gui=NONE      guifg=#404040   guibg=#8fff8b
    endif
" *************************************************************************
else
    hi Normal           cterm=NONE      ctermfg=white     ctermbg=NONE

    hi IncSearch        cterm=BOLD      ctermfg=black     ctermbg=red
    hi Search           cterm=NONE      ctermfg=black     ctermbg=red
    hi ErrorMsg         cterm=BOLD      ctermfg=white      ctermbg=124
" 16 > white 204 > darkred
    hi WarningMsg       cterm=BOLD      ctermfg=white      ctermbg=darkred
" 61 > white
    hi ModeMsg          cterm=BOLD      ctermfg=white      ctermbg=NONE
    hi MoreMsg          cterm=BOLD      ctermfg=white      ctermbg=NONE
    hi Question         cterm=BOLD      ctermfg=130     ctermbg=NONE

    hi StatusLine       cterm=BOLD      ctermfg=247     ctermbg=235
    hi User1            cterm=BOLD      ctermfg=46      ctermbg=235
    hi User2            cterm=BOLD      ctermfg=63      ctermbg=235
    hi StatusLineNC     cterm=NONE      ctermfg=244     ctermbg=235
    hi VertSplit        cterm=NONE      ctermfg=244     ctermbg=235

    hi WildMenu         cterm=BOLD      ctermfg=253     ctermbg=61

    hi MBENormal                        ctermfg=247     ctermbg=235
    hi MBEChanged                       ctermfg=253     ctermbg=235
    hi MBEVisibleNormal                 ctermfg=247     ctermbg=238
    hi MBEVisibleChanged                ctermfg=253     ctermbg=238

    hi DiffText         cterm=NONE      ctermfg=231     ctermbg=55
    hi DiffChange       cterm=NONE      ctermfg=231     ctermbg=17
    hi DiffDelete       cterm=NONE      ctermfg=231     ctermbg=52
    hi DiffAdd          cterm=NONE      ctermfg=231     ctermbg=22

    hi Folded           cterm=NONE      ctermfg=231     ctermbg=57
    hi FoldColumn       cterm=NONE      ctermfg=63      ctermbg=232

    hi Directory        cterm=NONE      ctermfg=46      ctermbg=NONE
    hi LineNr           cterm=NONE      ctermfg=darkgrey     ctermbg=NONE
    hi NonText          cterm=BOLD      ctermfg=blue      ctermbg=NONE
    hi SpecialKey       cterm=BOLD      ctermfg=blue     ctermbg=NONE
    hi Title            cterm=BOLD      ctermfg=white     ctermbg=NONE
    hi Visual           cterm=NONE      ctermfg=white     ctermbg=61
" cyan
    hi Comment          cterm=NONE      ctermfg=39     ctermbg=NONE
    hi Constant         cterm=NONE      ctermfg=215     ctermbg=NONE
" 215 > magenta
    hi String           cterm=NONE      ctermfg=gray     ctermbg=235
    hi Error            cterm=NONE      ctermfg=white     ctermbg=red
" 131 > blue
    hi Identifier       cterm=NONE      ctermfg=11			ctermbg=NONE
    hi Ignore           cterm=NONE
    hi Number           cterm=NONE      ctermfg=lightcyan     ctermbg=NONE
    hi PreProc          cterm=NONE      ctermfg=3			ctermbg=NONE
    hi Special          cterm=NONE      ctermfg=lightred     ctermbg=NONE
    hi SpecialChar      cterm=NONE      ctermfg=green     ctermbg=235
    hi Statement        cterm=NONE      ctermfg=cyan      ctermbg=NONE
    hi Todo             cterm=BOLD      ctermfg=17      ctermbg=143
    hi Type             cterm=NONE      ctermfg=13			ctermbg=NONE
    hi Underlined       cterm=BOLD      ctermfg=227     ctermbg=NONE
    hi TaglistTagName   cterm=BOLD      ctermfg=63      ctermbg=NONE

    hi Pmenu        cterm=NONE      ctermfg=253     ctermbg=242
    hi PmenuSel     cterm=BOLD      ctermfg=253     ctermbg=4
    hi PmenuSbar    cterm=BOLD      ctermfg=253     ctermbg=63
    hi PmenuThumb   cterm=BOLD      ctermfg=253     ctermbg=63

    hi SpellBad     cterm=underline ctermfg=red
    hi SpellRare    cterm=underline                 ctermbg=53
    hi SpellLocal   cterm=underline                 ctermbg=58
    hi SpellCap     cterm=underline                 ctermbg=23

    hi MatchParen   cterm=NONE      ctermfg=NONE    ctermbg=172

	hi ColorColumn ctermbg=4
    hi def BadWhitespace term=reverse ctermfg=16 ctermbg=001 gui=reverse guifg=#dc322f
    autocmd BufWinEnter * match BadWhitespace /\s\+$/
endif
