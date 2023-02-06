PACMAN='sudo pacman -S'

# upgrade system first
sudo pacman -Syu

$PACMAN git wget curl net-tools iotop rsync nload unzip pigz tmux htop \
        openssh mosh ntp \
        cmake lm_sensors \
        smartmontools \
        syslog-ng \
        dosfstools \
        community/pacutils \
        diff-so-fancy \
        vim zsh \
        inetutils

# wireless tools
$PACMAN iw wireless_tools wpa_supplicant

# python
$PACMAN python python-pip
