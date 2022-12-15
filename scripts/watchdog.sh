#!/bin/bash

############ FUNCTION TO READ CONFIG FILE #############################

get_config_var() {
lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
local val = line:match("^#?%s*"..key.."=(.*)$")
if (val ~= nil) then
print(val)
break
end
end
EOF
}

#######################################################################

PCONFIGFILE="/home/pi/portsdown/user/configs/portsdown_config.txt"

VIDEOINPUT=$(get_config_var videoinput $PCONFIGFILE)
LINKPIIP=$(get_config_var linkpiip $PCONFIGFILE)

pigs m 21 w                                   # Set BCM 21 (pin 40) to write
sleep 15                                      # Wait until after Calibration
RUNNING=1                                     # Set conditions so loop does not run

if pgrep -x "ffmpeg" > /dev/null              # If ffmpeg still running
then
  if  pgrep -x "limesdr_dvb" > /dev/null      # then test if limesdr_dvb running
  then
    pigs w 21 1                               # Both running, set PTT on
    RUNNING=0                                 # and set conditions for loop to run
  else
    pigs w 21 0                               # LimeSDR_DVB not running so ensure PTT off
  fi
else
    pigs w 21 0                               # ffmpeg not running so ensure PTT off
fi


while [ $RUNNING -eq 0 ]                      # Stay in this loop while transmitting
do
  sleep 10
  if pgrep -x "ffmpeg" > /dev/null            # If ffmpeg still running
  then
    if pgrep -x "limesdr_dvb" > /dev/null     # then test if limesdr_dvb still running
    then
      if [ "$VIDEOINPUT" == "linkpi" ]       # both running so check input device
      then
        if ping -c 1 -w 1 "$LINKPIIP" &> /dev/null  # ping 1 packet deadline 1 second
        then
          RUNNING=0                           # Ping OK, so keep running
        else
          RUNNING=1                           # Ping failed, so exit
        fi
      fi                                      # Future test for other devices here
    else
      RUNNING=1                               # limesdr_dvb not running, so exit
    fi
  else
    RUNNING=1                                 # ffmpeg not running, so exit
  fi
done

pigs w 21 0                                   # Turn PTT off
sudo killall ffmpeg                           # Kill ffmpeg if running
sudo killall limesdr_dvb                      # Kill limesdr_dvb if running

sleep 5                                       # Give time for everything to settle

/home/pi/portsdown/bin/limesdr_stopchannel &  # stop the limesdr

/home/pi/portsdown/scripts/rptr.sh &          # fork repeater start in a new process

exit             
