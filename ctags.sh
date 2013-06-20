#!/bin/sh

cd vim/

#if [ `uname -s` = 'Linux' ]
#then
#	CTAGS=/usr/bin/ctags
#else
#	CTAGS=/usr/local/bin/exctags
#fi
if [ -z `which ctags | sed '/not/d'` ]
then
	echo 'ctags not found.'
	exit 1
else
	CTAGS=`which ctags`
fi

$CTAGS -R --c-kinds=+p --fields=+S /usr/include/ && \
	echo $PWD/tags : create successfully!
