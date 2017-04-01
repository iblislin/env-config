PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools openssh iotop

# python
$PACMAN python python-pip
