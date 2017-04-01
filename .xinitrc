xset -b b off
xset r rate 450 60
xset s 1800 1800   # screen saver
xset dpms 1500 1500 1500
xmodmap ~/.Xmodmap
xrdb ~/.Xresources

xcompmgr &

redshift -O 4000 -b 0.9

fcitx &
urxvtd -q -o -f

# workrave &

exec awesome
