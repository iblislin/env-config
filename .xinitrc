xset -b b off
xset r rate 450 60
xset s 1800 1800   # screen saver
xset dpms 1500 1500 1500
xmodmap ~/.Xmodmap
xrdb ~/.Xresources

xcompmgr &

redshift -O 4000 -b 0.9

export XMODIFIERS='@im=fcitx'
export GTK_IM_MODULE=fcitx
export GTK3_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export QT4_IM_MODULE=fcitx
export QT5_IM_MODULE=fcitx
fcitx &

urxvtd -q -o -f

# workrave &

exec awesome
