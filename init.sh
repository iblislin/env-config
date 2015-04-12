#!/bin/sh

TRUE=1
FALSE=0

isLinix()
{
	if [ `uname -s` = 'Linux' ]
	then
		echo $TRUE
	else
		echo $FALSE
	fi
}

file=".cshrc .screenrc .gitconfig .pyrc vim zsh/zshenv zsh/zshrc"
rename_vim='.vim'
rename_zshenv='.zshenv'
rename_zshrc='.zshrc'

if [ `isLinix` = $TRUE ]
then
	REAL=`readlink -f $0`
else
	REAL=`realpath $0`
fi
BASE=`dirname $REAL`
LN='ln -sf'

mkdir -p $BASE/vim/backup $BASE/vim/tmp ~/bin

for f in $file
do
	if [ ! -e $BASE/$f ]
	then
		continue
	fi
	eval _rename=\$rename_${f#*/}
	if [ -z $_rename ]
	then
		_rename=$f
	fi
	if [ -e ~/$_rename ]
	then
		rm -f ~/$_rename
	fi
	echo "$BASE/$f -> ~/$_rename"
	$LN $BASE/$f ~/$_rename
done

git submodule update --init --recursive
git submodule sync

# vim pager
mkdir -p ~/bin
$LN $BASE/vimpager/vimpager ~/bin/
$LN $BASE/vimpager/vimcat ~/bin/

# zsh folder
ZSH=${ZSH:="$HOME/.zsh"}
if [ ! -e $ZSH ]
then
	echo 'Link zsh folder:' $ZSH
	$LN $BASE/zsh $ZSH
fi

$LN $BASE/.tmux.conf ~/
