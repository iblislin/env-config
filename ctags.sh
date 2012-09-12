#!/bin/sh

cd vim/

if [ `uname -s` = 'Linux' ]
then
	CTAGS=/usr/bin/ctags
else
	CTAGS=/usr/local/bin/exctags
fi
$CTAGS -R --c-kinds=+p --fields=+S /usr/include/ && \
	echo $PWD/tags : create successfully!
