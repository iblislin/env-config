#!/bin/sh

file=".cshrc .screenrc"
REAL=`realpath $0`
BASE=`dirname $REAL`
LN='ln -s'

ckfile()
{
	printf "$1 : "
		if [ ! -O $BASE/$1 ] 
		then
			printf 'Wrong Owner!\n'
		elif [ ! -w $BASE/$1 ]
		then
			printf 'Permission Deny!\n'
		elif [ ! -L $BASE/$1 ]
		then
			rm -rf ~/$1
			$LN $BASE/$1 ~/$1
			printf 'Done.\n'
		else
			printf	'Link existed.\n'
		fi
}

vim()
{
	ckfile ".vimrc"
	rm -rf ~/.vim
	mkdir -p ~/.vim/tmp ~/.vim/backup
	$LN $BASE/vim/code ~/.vim
	$LN $BASE/vim/colors ~/.vim
}

for i in $file
do
	ckfile $i;
	vim;
done
