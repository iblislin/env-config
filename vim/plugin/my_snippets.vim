" Templates: {{{1
" to add templates for new file type, see below
"
" "some new file type
" let g:template['newft'] = {}
" let g:template['newft']['keyword'] = "some abbrevation"
" let g:template['newft']['anotherkeyword'] = "another abbrevation"
" ...
"
" ---------------------------------------------
" C++ templates
let g:template['cpp']['ns'] = "using namespace ;\<left>"
"
" ---------------------------------------------
" Shell Script templates
let g:template['sh'] = {}
let g:template['sh']['cc'] = "#!/bin/sh"
let g:template['sh']['if'] = "if ".g:rs."...".g:re.
			\"\<cr>then\<cr>".g:rs."...".g:re."\<cr>fi"
let g:template['sh']['ife'] = "if ".g:rs."...".g:re.
			\"\<cr>then\<cr>".g:rs."...".g:re."\<cr>else\<cr>".
			\g:rs."...".g:re."\<cr>fi"
let g:template['sh']['for'] = "for ".g:rs."...".g:re.
			\" in ".g:rs."...".g:re."\<cr>do\<cr>".
			\g:rs."...".g:re."\<cr>done"
let g:template['sh']['while'] = "while ".g:rs."...".g:re.
			\"\<cr>do\<cr>".g:rs."...".g:re."\<cr>done"
let g:template['sh']['until'] = "until ".g:rs."...".g:re.
			\"\<cr>do\<cr>".g:rs."...".g:re."\<cr>done"
let g:template['sh']['case'] = "case ".g:rs."...".g:re." in\<cr>".
			\g:rs."...".g:re.") \<cr>".g:rs."...".g:re." ;;\<cr>".
			\g:rs."...".g:re.") \<cr>".g:rs."...".g:re." ;;\<cr>".
			\"*) \<cr>".g:rs."...".g:re." ;;\<cr>esac"
"
" ---------------------------------------------
" Tcsh Script templates
let g:template['tcsh'] = {}
let g:template['tcsh']['cc'] = "#!/bin/tcsh"
let g:template['tcsh']['if'] = "if ( ".g:rs."...".g:re.
			\" ) then\<cr>".g:rs."...".g:re."\<cr>endif"
let g:template['tcsh']['ife'] = "if ( ".g:rs."...".g:re.
			\" ) then\<cr>".g:rs."...".g:re."\<cr>else\<cr>".
			\g:rs."...".g:re."\<cr>endif"
let g:template['tcsh']['while'] = "while ( ".g:rs."...".g:re.
			\" )\<cr>".g:rs."...".g:re."\<cr>end"
let g:template['tcsh']['switch'] = "switch ( ".g:rs."...".g:re.
			\" )\<cr>case ".g:rs."...".g:re." :\<cr>".
			\g:rs."...".g:re."\<cr>breaksw\<cr>case ".
			\g:rs."...".g:re." :\<cr>".g:rs."...".g:re.
			\"\<cr>breaksw\<cr>default:\<cr>".
			\g:rs."...".g:re."\<cr>breaksw\<cr>endsw"
let g:template['tcsh']['for'] = "foreach ".g:rs."key".g:re.
			\" ( ".g:rs."list".g:re." )\<cr>".
			\g:rs."...".g:re."\<cr>end"

let g:template['csh'] = g:template['tcsh']
"
" ---------------------------------------------
