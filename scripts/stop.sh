#!/bin/bash

pigs w 21 0                                   # Turn PTT off
sudo killall ffmpeg
sudo killall limesdr_dvb
sudo killall watchdog.sh

sleep 2

sudo rm videots >/dev/null 2>/dev/null

/home/pi/portsdown/bin/limesdr_stopchannel

exit

