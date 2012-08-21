#!/bin/sh

cd $HOME/.vim/
/usr/local/bin/exctags -R --c-kinds=+p --fields=+S /usr/include/ && \
	echo $HOME/.vim/tags : create successfully!
