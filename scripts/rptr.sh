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

VIDEOSOURCE=$(get_config_var videosource $PCONFIGFILE)
LINKPIIP=$(get_config_var linkpiip $PCONFIGFILE)
FREQ_OUTPUT=$(get_config_var freqoutput $PCONFIGFILE)
SYMBOLRATE_K=$(get_config_var symbolrate $PCONFIGFILE)
MODTYPE=$(get_config_var modulation $PCONFIGFILE)
OUTPUTDEVICE=$(get_config_var outputdevice $PCONFIGFILE)
LIME_GAIN=$(get_config_var limegain $PCONFIGFILE)
FEC=$(get_config_var fec $PCONFIGFILE)
CONSTLN=$(get_config_var constellation $PCONFIGFILE)
PILOT=$(get_config_var pilots $PCONFIGFILE)
FRAME=$(get_config_var frames $PCONFIGFILE)
SERVICEPROVIDER=$(get_config_var serviceprovider $PCONFIGFILE)
CALL=$(get_config_var call $PCONFIGFILE)
PIDVIDEO=$(get_config_var pidvideo $PCONFIGFILE)
PIDAUDIO=$(get_config_var pidaudio $PCONFIGFILE)
PIDPMTSTART=$(get_config_var pidpmtstart $PCONFIGFILE)


UPSAMPLE="4"
BAND_GPIO="2"


######################### CALCULATE TS BITRATE ###########################

if [ "$PILOT" == "on" ]; then
  PILOTS="-p"
else
  PILOTS=" "
fi

if [ "$FRAME" == "short" ]; then
  FRAMES="-v"
else
  FRAMES=" "
fi

BITRATE_TS="$($PATHBIN"/dvb2iq" -s $SYMBOLRATE_K -f $FEC \
             -d -r $UPSAMPLE -m $MODTYPE -c $CONSTLN $PILOTS $FRAMES )"

####################### SORT LIME CONFIG #################################

# Make sure Lime gain is sensible
if [ "$LIME_GAIN" -lt "6" ]; then
  LIMEGAIN=6
fi

if [ "$OUTPUTDEVICE" == "limedvb" ]; then
  FPGA="-F"
  let DIGITAL_GAIN=($LIME_GAIN*31)/100
else
  FPGA=" "
  DIGITAL_GAIN=30
fi
LIME_GAINF=`echo - | awk '{print '$LIME_GAIN' / 100}'`

if [ "$OUTPUTDEVICE" == "limeusb" ]; then
  LIMETYPE="-U"
else
  LIMETYPE=" "
fi

################### CLEAN UP ############################################

sudo killall ffmpeg
sudo killall limesdr_dvb
sleep 1
$PATHBIN"/limesdr_stopchannel"    # stop the limesdr
sudo rm videots >/dev/null 2>/dev/null
mkfifo videots

####################### RUN LIME ##########################################

$PATHBIN"/limesdr_dvb" -i videots -s "$SYMBOLRATE_K"000 -f "$FEC" -r $UPSAMPLE \
  -m $MODTYPE -c $CONSTLN $PILOTS $FRAMES \
  -t "$FREQ_OUTPUT"e6 -g $LIME_GAINF -q 1 "$FPGA" -D $DIGITAL_GAIN -e $BAND_GPIO $LIMETYPE &

####################### RUN FFMPEG ###################################

if [ "$VIDEOSOURCE" == "linkpi_srt" ]; then

  ffmpeg -loglevel debug -thread_queue_size 1024 -fflags nobuffer\
    -protocol_whitelist srt -probesize 500000 -analyzeduration 500000 \
    -i "srt://"$LINKPIIP":9001?pkt_size=1316" \
    -c:v copy -c:a copy \
    -f mpegts -blocksize 1880 \
    -mpegts_original_network_id 1 -mpegts_transport_stream_id 1 \
    -mpegts_service_id "1" -mpegts_service_type 25\
    -mpegts_pmt_start_pid "$PIDPMTSTART" -streamid 0:"$PIDVIDEO" -streamid 1:"$PIDAUDIO" \
    -metadata service_provider="$SERVICEPROVIDER" -metadata service_name="$CALL" \
    -mpegts_flags system_b \
    -muxrate "$BITRATE_TS" -y videots &

fi

if [ "$VIDEOSOURCE" == "linkpi_rtsp" ]; then

  ffmpeg -loglevel debug -thread_queue_size 1024 \
    -rtsp_transport tcp -max_delay 50000 \
     -probesize 500000 -analyzeduration 500000 \
    -i "rtsp://"$LINKPIIP"/stream0?overrun_nonfatal=1" \
    -c:v copy -c:a copy \
    -f mpegts -blocksize 1880 \
    -mpegts_original_network_id 1 -mpegts_transport_stream_id 1 \
    -mpegts_service_id "1" -mpegts_service_type 25 \
    -mpegts_pmt_start_pid "$PIDPMTSTART" -streamid 0:"$PIDVIDEO" -streamid 1:"$PIDAUDIO" \
    -metadata service_provider="$SERVICEPROVIDER" -metadata service_name="$CALL" \
    -metadata title="Amateur TV Repeater" \
    -mpegts_flags system_b \
    -muxrate "$BITRATE_TS" -y videots &

fi

/home/pi/portsdown/scripts/watchdog.sh &



