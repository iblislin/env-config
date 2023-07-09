#!/bin/sh

# NVIM_CONFIG

CONFIGDIR=~/.config/nvim
SITEDIR=~/.local/share/nvim/site
PACKDIR=$SITEDIR/pack

mkdir -p $PACKDIR $CONFIGDIR

git clone --depth 1 https://github.com/wbthomason/packer.nvim $PACKDIR/packer/start/packer.nvim
