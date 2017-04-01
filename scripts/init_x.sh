
PACMAN='sudo pacman -Sy'

$PACMAN xorg \
        xorg-drivers \
        xorg-utils

$PACMAN rxvt-unicode

# wm
$PACMAN awesome

# sound
$PACMAN alsa-oss alsa-plugins alsa-tools alsa-utils

# utils
$PACMAN xdg-utils

# font
$PACMAN ttf-droid noto-fonts noto-fonts-cjk noto-fonts-emoji

# browser
$PACMAN firefox thunderbird
