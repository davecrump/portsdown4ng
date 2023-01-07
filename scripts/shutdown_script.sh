#!/bin/bash

# set -x

# Called by pi-sdn to tidy up and shutdown.

do_stop_transmit()
{
  # Kill the key processes as nicely as possible
  sudo killall ffmpeg >/dev/null 2>/dev/null
  sudo killall limesdr_send >/dev/null 2>/dev/null
  sudo killall limesdr_dvb >/dev/null 2>/dev/null

  # Then pause and make sure that ffmpeg has really been stopped (needed at high SRs)
  sleep 0.1
  sudo killall -9 ffmpeg >/dev/null 2>/dev/null

  # And make sure limesdr_send has been stopped
  sudo killall -9 limesdr_send >/dev/null 2>/dev/null
  sudo killall -9 limesdr_dvb >/dev/null 2>/dev/null

  # Reset the LimeSDR
  /home/pi/portsdown/bin/limesdr_stopchannel & # Fork process as this sometimes hangs
}

pigs w 21 0                                   # Turn PTT off

do_stop_transmit

sleep 5  #1

# Make sure that the swap file doesn't cause a hang
sudo swapoff -a

sudo shutdown now

exit
