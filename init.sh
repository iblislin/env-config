#!/bin/sh
REAL=`realpath $0`
BASE=`dirname $REAL`
LN='ln -s'

echo Checking File:
for i in .cshrc .screenrc .vimrc
do
	j=${HOME}/${i}
	printf '\t'$j'\t\t'
	if [ ! -e $j ]
	then
		printf 'Not exsits! \n'
		printf '\t\t\t Creating ... '
		$LN $BASE/$i $j
		printf 'Done.\n'
	elif [ ! -O $j ] 
	then
		printf 'Wrong Owner !\n'
	elif [ ! -w $j ]
	then
		printf 'Not writtable! \n'
	elif [ ! -L $j ]
	then
		printf 'Not a symbolic link! \n'
		printf '\t\t\t Replacing ... '
		rm -rf $j
		$LN $BASE/$i $j
		printf 'Done.\n'
	else
		printf	'exsits.\n'
	fi
done

