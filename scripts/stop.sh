#!/bin/bash

sudo killall ffmpeg
sudo killall limesdr_dvb

sleep 2

PATHRPI="/home/pi/portsdown/bin"

sudo rm videots >/dev/null 2>/dev/null


/home/pi/portsdown/bin/limesdr_stopchannel



