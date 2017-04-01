PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools openssh iotop rsync mosh

# python
$PACMAN python python-pip
