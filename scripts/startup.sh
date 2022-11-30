#!/bin/bash

# set -x

# This script is sourced from .bashrc at boot, but not at ssh session start
# to select the user's selected start-up option.
# Dave Crump 20221126

############ Set Environment Variables ###############

PATHSCRIPT=/home/pi/portsdown/scripts
PMAINCONFIGFILE="/home/pi/portsdown/user/configs/main_config.txt"
PRPTRCONFIGFILE="/home/pi/portsdown/user/configs/rptr_config.txt"

############ Function to Read from Config File ###############

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

######################### Start here #####################

# Read the desired start-up behaviour
MODE_STARTUP=$(get_config_var startup $PMAINCONFIGFILE)

# If pi-sdn is not running, check if it is required to run
#ps -cax | grep 'pi-sdn' >/dev/null 2>/dev/null
#RESULT="$?"
#if [ "$RESULT" -ne 0 ]; then
#  if [ -f /home/pi/.pi-sdn ]; then
#    . /home/pi/.pi-sdn
#  fi
#fi

# Facility to Disable WiFi
# Calls .wifi_off if present and runs "sudo ip link set wlan0 down"
#if [ -f ~/.wifi_off ]; then
#    . ~/.wifi_off
#fi

# If a boot session, put up the BATC Splash Screen, and then kill the process
#sudo fbi -T 1 -noverbose -a /home/pi/portsdown/templates/screens/BATC_Black.png >/dev/null 2>/dev/null
#(sleep 1; sudo killall -9 fbi >/dev/null 2>/dev/null) &  ## kill fbi once it has done its work

# Map the touchscreen event to /dev/input/touchscreen

#sudo rm /dev/input/touchscreen >/dev/null 2>/dev/null
#cat /proc/bus/input/devices | grep 'H: Handlers=mouse0 event0' >/dev/null 2>/dev/null
#RESULT="$?"
#if [ "$RESULT" -eq 0 ]; then
#  sudo ln /dev/input/event0 /dev/input/touchscreen
#fi
#cat /proc/bus/input/devices | grep 'H: Handlers=mouse0 event1' >/dev/null 2>/dev/null
#RESULT="$?"
#if [ "$RESULT" -eq 0 ]; then
#  sudo ln /dev/input/event1 /dev/input/touchscreen
#fi
#cat /proc/bus/input/devices | grep 'H: Handlers=mouse0 event2' >/dev/null 2>/dev/null
#RESULT="$?"
#if [ "$RESULT" -eq 0 ]; then
#  sudo ln /dev/input/event2 /dev/input/touchscreen
#fi

# Select the appropriate action

case "$MODE_STARTUP" in
  Prompt)
    # Go straight to command prompt
    return
  ;;
  Console)
    # Start the menu if this is an ssh session
    if [ "$SESSION_TYPE" == "ssh" ]; then
      /home/pi/portsdown/scripts/menu.sh menu
    fi
    return
  ;;
  Display_boot)
    # Start the Touchscreen Scheduler
    source /home/pi/portsdown/scripts/scheduler.sh
    #return
  ;;
  Langstone_boot)
    # Start the Touchscreen Scheduler
    source /home/pi/portsdown/scripts/scheduler.sh
    #return
  ;;
  Bandview_boot)
    # Start the Touchscreen Scheduler
    source /home/pi/portsdown/scripts/scheduler.sh
    #return
  ;;
  rptr)
    sudo pigpiod
      (sleep 5; /home/pi/portsdown/scripts/rptr.sh) &
    return
  ;;
  *)
    return
  ;;
esac


