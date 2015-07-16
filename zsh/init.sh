#!/bin/sh

##############################################
#  utils
##############################################

dir(){
	if [ -z $1 ]
	then
		return
	fi
	if [ ! -e $1 ]
	then
		return
	fi

	tmp=`realpath $1`
	echo `dirname $tmp`
}

##############################################
#  vars
##############################################

REPO_LIST='https://github.com/zsh-users/zsh-syntax-highlighting.git'
REPO_DIR=`dir $0`/repo

cd $REPO_DIR
echo "in $REPO_DIR"

for repo in $REPO_LIST
do
	 git clone $repo
done
