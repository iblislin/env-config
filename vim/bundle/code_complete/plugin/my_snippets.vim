" Templates: {{{
" to add templates for new file type, see below
"
" "some new file type
" let g:template['newft'] = {}
" let g:template['newft']['keyword'] = "some abbrevation"
" let g:template['newft']['anotherkeyword'] = "another abbrevation"
" ...
"
" --------------------------------------------- }}}
" C++ templates"{{{
let g:template['cpp']['forj'] = "for(int j=0; j<".g:rs."...".g:re."; j++)"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>"
let g:template['cpp']['fori'] = "for(int i=0; i<".g:rs."...".g:re."; i++)"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>"
let g:template['cpp']['ns'] = "using namespace ;\<left>"
let g:template['cpp']['class'] = "class ".g:rs."...".g:re.
			\"\<cr>{"
			\."\<cr>public:"
			\."\<cr>"
			\."\<cr>private:"
			\."\<cr>};"
"
" ---------------------------------------------"}}}
" Shell Script templates"{{{
let g:template['sh'] = {}
let g:template['sh']['cc'] = "#!/bin/sh\<cr>"
let g:template['sh']['if'] = "if ".g:rs."...".g:re.
			\"\<cr>then\<cr>".g:rs."...".g:re."\<cr>fi"
let g:template['sh']['ife'] = "if ".g:rs."...".g:re.
			\"\<cr>then\<cr>".g:rs."...".g:re."\<cr>else\<cr>".
			\g:rs."...".g:re."\<cr>fi"
let g:template['sh']['for'] = "for ".g:rs."...".g:re.
			\" in ".g:rs."...".g:re."\<cr>do\<cr>".
			\g:rs."...".g:re."\<cr>done\<cr>"
let g:template['sh']['while'] = "while ".g:rs."...".g:re.
			\"\<cr>do\<cr>".g:rs."...".g:re."\<cr>done\<cr>"
let g:template['sh']['until'] = "until ".g:rs."...".g:re.
			\"\<cr>do\<cr>".g:rs."...".g:re."\<cr>done\<cr>"
let g:template['sh']['case'] = "case ".g:rs."...".g:re." in\<cr>".
			\g:rs."...".g:re.") \<cr>".g:rs."...".g:re." ;;\<cr>".
			\g:rs."...".g:re.") \<cr>".g:rs."...".g:re." ;;\<cr>".
			\"*) \<cr>".g:rs."...".g:re." ;;\<cr>esac\<cr>"
"
" ---------------------------------------------"}}}
" Zsh Script templates"{{{
let g:template['zsh'] = g:template['sh']
let g:template['zsh']['select'] = "select ".g:rs."...".g:re.
			\" in ".g:rs."...".g:re."\<cr>do\<cr>".
			\g:rs."...".g:re."\<cr>done\<cr>"
let g:template['zsh']['repeat'] = "repeat ".g:rs."...".g:re.
			\" in ".g:rs."...".g:re."\<cr>do\<cr>".
			\g:rs."...".g:re."\<cr>done\<cr>"
let g:template['zsh']['fun'] = "function ".g:rs."...".g:re."()\<cr>".
			\"{\<cr>".
			\g:rs."...".g:re."\<cr>".
			\"}\<cr>"
"
" ---------------------------------------------"}}}
" Tcsh Script templates"{{{
let g:template['tcsh'] = {}
let g:template['tcsh']['cc'] = "#!/bin/tcsh\<cr>"
let g:template['tcsh']['if'] = "if ( ".g:rs."...".g:re.
			\" ) then\<cr>".g:rs."...".g:re."\<cr>endif"
let g:template['tcsh']['ife'] = "if ( ".g:rs."...".g:re.
			\" ) then\<cr>".g:rs."...".g:re."\<cr>else\<cr>".
			\g:rs."...".g:re."\<cr>endif"
let g:template['tcsh']['while'] = "while ( ".g:rs."...".g:re.
			\" )\<cr>".g:rs."...".g:re."\<cr>end\<cr>"
let g:template['tcsh']['switch'] = "switch ( ".g:rs."...".g:re.
			\" )\<cr>case ".g:rs."...".g:re." :\<cr>".
			\g:rs."...".g:re."\<cr>breaksw\<cr>case ".
			\g:rs."...".g:re." :\<cr>".g:rs."...".g:re.
			\"\<cr>breaksw\<cr>default:\<cr>".
			\g:rs."...".g:re."\<cr>breaksw\<cr>endsw\<cr>"
let g:template['tcsh']['for'] = "foreach ".g:rs."...".g:re.
			\" ( ".g:rs."...".g:re." )\<cr>".
			\g:rs."...".g:re."\<cr>end\<cr>"

let g:template['csh'] = g:template['tcsh']
"
" ---------------------------------------------"}}}
"  Vim Script templates"{{{
let g:template['vim'] = {}
let g:template['vim']['if'] = 'if '.g:rs."...".g:re.
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>endif"
let g:template['vim']['ife'] = 'if '.g:rs."...".g:re.
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>else".
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>endif"
let g:template['vim']['while'] = "while ".g:rs."...".g:re.
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>endwhile\<cr>"
let g:template['vim']['for'] = "for ".g:rs."...".g:re." in ".g:rs."...".g:re.
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>endfor\<cr>"
let g:template['vim']['fun'] = "function! ".g:rs."...".g:re."(".g:rs."...".g:re.")".
			\"\<cr>".g:rs."...".g:re.
			\"\<cr>endfunction\<cr>"
let g:template['vim']['cc'] = '.g:rs."...".g:re.'
let g:template['vim']['cr'] = "\\<cr>"
"
" --------------za-------------------------------"}}}
"  PHP templates"{{{
let g:template['php'] = {}
let g:template['php']['cc'] = "<?php\<cr>".g:rs."...".g:re.
			\"\<cr>?>"
let g:template['php']['if'] = "if( ".g:rs."...".g:re. " )".
			\"\<cr>{\<cr>".g:rs."...".g:re."\<cr>}"
let g:template['php']['ifil'] = "<?php if( ".g:rs."...".g:re. " ): ?>".
			\"\<cr>".g:rs."...".g:re."\<cr><?php endif; ?>"
let g:template['php']['ife'] = "if( ".g:rs."...".g:re. " )".
			\"\<cr>{\<cr>".g:rs."...".g:re."\<cr>}".
			\"\<cr>else\<cr>{\<cr>".g:rs."...".g:re."\<cr>}"
let g:template['php']['ifeil'] = "<?php if( ".g:rs."...".g:re. " ): ?>".
			\"\<cr>".g:rs."...".g:re."\<cr><?php else: ?>".
			\"\<cr>".g:rs."...".g:re."\<cr><?php endif; ?>"
let g:template['php']['elseif'] = "elseif ( ".g:rs."...".g:re." )"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
let g:template['php']['else'] = "else"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
let g:template['php']['while'] = g:template['c']['while']
let g:template['php']['for'] = g:template['c']['for']
let g:template['php']['fori'] = "for($i=0; $i<".g:rs."...".g:re."; $i++)"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>"
let g:template['php']['foreach'] = "foreach( ".g:rs."...".g:re." as ".g:rs."...".g:re." )"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}\<cr>"
let g:template['php']['foreachil'] = "<?php foreach( ".g:rs."...".g:re." as ".g:rs."...".g:re." ): ?>"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr><?php endforeach; ?>"
let g:template['php']['foreachk'] = "foreach( ".g:rs."...".g:re." as ".g:rs."...".g:re." => ".g:rs."...".g:re." )"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}\<cr>"
let g:template['php']['foreachkil'] = "<?php foreach( ".g:rs."...".g:re." as ".g:rs."...".g:re." => ".g:rs."...".g:re." ): ?>"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr><?php endforeach; ?>"
let g:template['php']['switch'] = g:template['c']['switch']
let g:template['php']['case'] = g:template['c']['case']
let g:template['php']['fun'] = "function ".g:rs."...".g:re."(".g:rs."...".g:re.")"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>"
let g:template['php']['class'] = "class ".g:rs."...".g:re.
			\"\<cr>{"
			\."\<cr>function __construct(".g:rs."...".g:re.")"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>function __destruct()"
			\."\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>}"
			\."\<cr>"
let g:template['php']['interface'] = "interface ".g:rs."...".g:re.
			\"\<cr>{"
			\."\<cr>".g:rs."...".g:re.
			\"\<cr>}"
			\."\<cr>"
"
" ---------------------------------------------"}}}
"  Javascript templates"{{{
let g:template['javascript'] = {}
let g:template['javascript']['for'] = g:template['c']['for']
"
" ---------------------------------------------"}}}
"  Perl templates"{{{
let g:template['perl'] = {}
let g:template['perl']['cc'] = "#!/usr/bin/env perl\<cr>"
"
" ---------------------------------------------"}}}
