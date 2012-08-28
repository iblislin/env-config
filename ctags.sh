#!/bin/sh

cd vim/
/usr/local/bin/exctags -R --c-kinds=+p --fields=+S /usr/include/ && \
	echo $PWD/tags : create successfully!
