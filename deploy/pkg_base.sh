#!/bin/sh

export PACKAGEROOT='ftp://ftp.tw.freebsd.org'

pkg_list='vim psearch nload git'

pkg_add -r $pkg_list
