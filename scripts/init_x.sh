
PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN xorg \
        xorg-drivers \
        xorg-xinit

$PACMAN rxvt-unicode

# wm
$PACMAN awesome xcompmgr

# sound
$PACMAN alsa-oss alsa-plugins alsa-tools alsa-utils \
        pulseaudio-alsa pulseaudio pavucontrol

# utils
$PACMAN xdg-utils

# font
$PACMAN ttf-droid \
        noto-fonts noto-fonts-cjk noto-fonts-emoji \
        adobe-source-code-pro-fonts adobe-source-sans-pro-fonts \
        adobe-source-serif-pro-fonts adobe-source-han-sans-tw-fonts \
        adobe-source-han-sans-jp-fonts \
        powerline-fonts \
        wqy-bitmapfont wqy-microhei wqy-microhei-lite wqy-zenhei
# yaourt -S aur/nerd-fonts-fira-code aur/nerd-fonts-complete

# browser
$PACMAN firefox thunderbird evince chromium

# IME
$PACMAN fcitx-im fcitx-rime librime fcitx-configtool

# musci
$PACMAN mpd mpc ncmpc

# latex
# $PACMAN texlive-most texlive-lang texlive-langcjk

# wine
# $PACMAN wine winetricks wine-mono
# $PACMAN multilib/lib32-mpg123

# for HS
# winetricks vcrun2015
# lib32-alsa-lib lib32-openal lib32-gnutls lib32-mpg123 lib32-libldap
# samba multilib/lib32-krb5

# image
$PACMAN feh imagemagick
