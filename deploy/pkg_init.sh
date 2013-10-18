#!/bin/sh

export PACKAGEROOT='ftp://ftp.tw.freebsd.org'

pkg_list='screen sudo zsh'

for i in $pkg_list
do
	pkg_add -r i
done

zsh_path=`cat /etc/shells | grep -m 1 "/zsh"`

echo 'Switching shell to zsh...'
chsh -s $zsh_path
echo 'Input a user for witching to zsh:'
read user
chsh -s $zsh_path $user
echo 'Done.'
