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

############### SET CONFIGURATION FROM FILE############################

MCONFIGFILE="/home/pi/portsdown/user/configs/main_config.txt"
PCONFIGFILE="/home/pi/portsdown/user/configs/portsdown_config.txt"
PATHBIN="/home/pi/portsdown/bin"

VIDEOINPUT=$(get_config_var videoinput $PCONFIGFILE)
LINKPIIP=$(get_config_var linkpiip $PCONFIGFILE)
FREQ_OUTPUT=$(get_config_var freqoutput $PCONFIGFILE)
SYMBOLRATE_K=$(get_config_var symbolrate $PCONFIGFILE)
MODTYPE=$(get_config_var modulation $PCONFIGFILE)

################### CLEAN UP ############################################

sudo killall ffmpeg
sudo killall limesdr_dvb
sleep 1
$PATHBIN"/limesdr_stopchannel"    # stop the limesdr
sudo rm videots >/dev/null 2>/dev/null
mkfifo videots

#/home/pi/portsdown/bin/limesdr_dvb -i videots -s 1000000 -f 2/3 -r 4 -m DVBS2 -c QPSK  \
#  -t 1255e6 -g 0.90 -q 1 -D 30 -e 2 &

$PATHBIN"/limesdr_dvb" -i videots -s "$SYMBOLRATE_K"000 -f 2/3 -r 4 -m DVBS2 -c QPSK  \
  -t "$FREQ_OUTPUT"e6 -g 0.90 -q 1 -F -D 30 -e 2 &

ffmpeg -loglevel debug -thread_queue_size 1024 -fflags nobuffer\
  -protocol_whitelist srt -probesize 500000 -analyzeduration 500000 \
  -i "srt://"$LINKPIIP":9001?pkt_size=1316" \
  -c:v copy -c:a copy \
  -f mpegts -blocksize 1880 \
  -mpegts_original_network_id 1 -mpegts_transport_stream_id 1 \
  -mpegts_service_id "1" -mpegts_service_type 25\
  -mpegts_pmt_start_pid "4095" -streamid 0:"257" -streamid 1:"258" \
  -metadata service_provider="IO91CC" -metadata service_name="GB3HV" \
  -mpegts_flags system_b \
  -muxrate 1322253 -y videots &

/home/pi/portsdown/scripts/watchdog.sh &



