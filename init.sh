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

file=".cshrc .screenrc .gitconfig .pythonrc vim zsh/zshenv zsh/zshrc .tmux.conf .tmux-inner.conf .npmrc .erlang .hgrc .atom .latexmkrc .fonts.conf"
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
LN='ln -sfv'

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

# X config
cp $BASE/.Xmodmap ~/
cp $BASE/.Xresources ~/
cp $BASE/.xinitrc ~/

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

# bin folder
for f in `find $BASE/bin -type f`
do
	$LN $f $HOME/bin/
done


# julia
JLDIR=$HOME/.julia/config
mkdir -p $JLDIR
$LN $BASE/startup.jl $JLDIR/

# folders
for f in git node go code
do
    mkdir -p $HOME/${f}
done

# GPG
if [ ! -d "$HOME/.gnupg" ]
then
    mkdir "$HOME/.gnupg"
    chmod 700 "$HOME/.gnupg"
fi
$LN "$BASE/gnupg/gpg.conf" "$HOME/.gnupg/"
$LN "$BASE/gnupg/gpg-agent.conf" "$HOME/.gnupg/"

# X11 related
XCONFIG="$HOME/.config"
mkdir -p $XCONFIG

$LN $BASE/powerline $XCONFIG
$LN $BASE/awesome4 $XCONFIG/awesome
$LN $BASE/.emacs.d $HOME


$BASE/bin/fetch-pubkeys

# install diff-so-fancy
curl https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy > ~/bin/diff-so-fancy
chmod +x ~/bin/diff-so-fancy
