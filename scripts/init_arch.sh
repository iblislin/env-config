PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools openssh iotop rsync

# python
$PACMAN python python-pip
