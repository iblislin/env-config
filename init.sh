#!/bin/sh

file=".cshrc .screenrc .vimrc"
REAL=`realpath $0`
BASE=`dirname $REAL`
LN='ln -s'

function ckfile()
{
	echo $1 : 
		if [ ! -O $j ] 
		then
			printf 'Wrong Owner!\n'
		elif [ ! -w $j ]
		then
			printf 'Permission Deny!\n'
		elif [ ! -L $j ]
		then
			rm -rf $j
			$LN $BASE/$i $j
			printf 'Done.\n'
		else
			printf	'Link existed.\n'
		fi
}
