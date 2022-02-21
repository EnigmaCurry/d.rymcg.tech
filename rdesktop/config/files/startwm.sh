#!/bin/bash
/usr/bin/pulseaudio --start

## Set solid color wallpaper:
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorrdp0/workspace0/image-style -s 0
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorrdp0/workspace0/rgba1 -s 5 -s 5 -s 5 -s 1


/usr/bin/startxfce4 > /dev/null 2>&1
