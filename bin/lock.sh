# this block is copied from the .xinitrc
xset s 1800 1800   # screen saver
xset dpms 1500 1500 1500

betterlockscreen -l dim --off 20 &

sleep 5 && xset dpms force off
