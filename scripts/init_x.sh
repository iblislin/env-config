
PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN xorg \
        xorg-drivers \
        xorg-utils

$PACMAN rxvt-unicode

# wm
$PACMAN awesome

# sound
$PACMAN alsa-oss alsa-plugins alsa-tools alsa-utils \
        pulseaudio-alsa pulseaudio

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

# browser
$PACMAN firefox thunderbird evince chromium

# IME
$PACMAN fcitx-im fcitx-rime librime fcitx-configtool

# musci
$PACMAN mpd mpc ncmpc
