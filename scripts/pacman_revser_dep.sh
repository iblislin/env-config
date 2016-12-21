#!/bin/sh

# libpng + libtiff
pacman -S `cat <(pactree -lrud1 libpng) <(pactree -lrud1 libtiff) | sort | uniq`
