#!/bin/bash

sudo killall ffmpeg
sudo killall limesdr_dvb

sleep 1

PATHRPI="/home/pi/portsdown/bin"

sudo rm videots >/dev/null 2>/dev/null
mkfifo videots

/home/pi/portsdown/bin/limesdr_dvb -i videots -s 1000000 -f 2/3 -r 4 -m DVBS2 -c QPSK  \
  -t 1255e6 -g 0.98 -q 1 -F -D 30 -e 2 &

ffmpeg -loglevel debug -thread_queue_size 2048 \
  -i srt://192.168.2.141:9001?overrun_nonfatal=1 \
  -c:v copy -c:a copy \
  -f mpegts -blocksize 1880 \
  -mpegts_original_network_id 1 -mpegts_transport_stream_id 1 \
  -mpegts_service_id "1" -mpegts_service_type 25\
  -mpegts_pmt_start_pid "4095" -streamid 0:"257" -streamid 1:"258" \
  -metadata service_provider="IO91CC" -metadata service_name="GB3HV" \
  -muxrate 1322253 -y videots &


