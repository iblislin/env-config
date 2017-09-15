PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools iotop rsync nload unzip \
        openssh mosh \
        feh imagemagick \
        cmake lm_sensors \
        smartmontools \
        syslog-ng \
        dosfstools

# python
$PACMAN python python-pip
