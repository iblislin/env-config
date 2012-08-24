#!/bin/sh

file=".cshrc .screenrc .gitconfig"
REAL=`realpath $0`
BASE=`dirname $REAL`
LN='ln -s'

ckfile()
{
	printf "$1 : "
		if [ ! -O $HOME/$1 ] 
		then
			printf 'Wrong Owner!\n'
		elif [ ! -w $HOME/$1 ]
		then
			printf 'Permission Deny!\n'
		elif [ ! -L $HOME/$1 ]
		then
			rm -rf $HOME/$1
			$LN $BASE/$1 $HOME/$1
			printf 'Done.\n'
		else
			printf	'Link existed.\n'
		fi
}

vim()
{
	ckfile ".vimrc"
	if [ -d $HOME/.vim ]
	then
		rm -rf $HOME/.vim
		$LN $BASE/vim $HOME/.vim
	fi
	sh ./ctags.sh
}

for i in $file
do
	ckfile $i;
done

vim;

git submodule init
git submodule sync
git submodule update
