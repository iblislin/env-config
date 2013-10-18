#!/bin/sh

export PACKAGEROOT='ftp://ftp.tw.freebsd.org'

pkg_list='screen sudo zsh'

pkg_add -r $pkg_list

zsh_path=`cat /etc/shells | grep -m 1 "/zsh"`

echo 'Switching shell to zsh...'
chsh -s $zsh_path
echo 'Input a user for witching to zsh:'
read user
chsh -s $zsh_path $user
echo 'Done.'
