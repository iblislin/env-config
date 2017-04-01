PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools iotop rsync \
        openssh mosh \
        feh imagemagick

# python
$PACMAN python python-pip
