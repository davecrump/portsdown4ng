#!/bin/bash

PMAINCONFIGFILE="/home/pi/portsdown/user/configs/main_config.txt"

############ Function to Write to Config File ###############

set_config_var() {
lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
if line:match("^#?%s*"..key.."=.*$") then
line=key.."="..value
made_change=true
end
print(line)
end
if not made_change then
print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

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

############ Function to Read value with - from Config File ###############

get-config_var() {
lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
local val = line:match("^#?%s*"..key.."=[+-]?(.*)$")
if (val ~= nil) then
print(val)
break
end
end
EOF
}

############################################################################

do_autostart_setup()
{
  MODE_STARTUP=$(get_config_var startup $PMAINCONFIGFILE)
  Radio1=OFF
  Radio2=OFF
  Radio3=OFF
  Radio4=OFF
  Radio5=OFF
  Radio6=OFF
  Radio7=OFF
  Radio8=OFF
  Radio9=OFF
  Radio10=OFF
  Radio11=OFF
  Radio12=OFF

  case "$MODE_STARTUP" in
    Prompt)
      Radio1=ON
    ;;
    Console)
      Radio2=ON
    ;;
    Display_boot)
      Radio3=ON
    ;;
    Langstone_boot)
      Radio4=ON
    ;;
    Bandview_boot)
      Radio5=ON
    ;;
    rptr)
      Radio6=ON
    ;;
    *)
      Radio1=ON
    ;;
  esac

  chstartup=$(whiptail --title "Select Boot Behaviour" --radiolist \
   "Select Boot Behaviour" 20 78 12 \
   "Prompt" "Linux Command Prompt" $Radio1 \
   "Console" "Console Menu" $Radio2 \
   "Display_boot" "Boot to Portsdown Touchscreen" $Radio3 \
   "Langstone_boot" "Boot to the Langstone TRX" $Radio4 \
   "Bandview_boot" "Boot to Bandviewer" $Radio5 \
   "rptr" "Boot up to Repeater TX" $Radio6 \
   3>&2 2>&1 1>&3)

  if [ $? -eq 0 ]; then
     set_config_var startup "$chstartup" $PMAINCONFIGFILE
  fi

  # If Repeater selected, set up cron for 12-hourly reboot
  # Also do it for keyed or continuous TX
  if [[ "$chstartup" == "rptr" ]]; then
    sudo crontab /home/pi/portsdown/templates/scripts/rptrcron
  else
    sudo crontab /home/pi/portsdown/templates/scripts/blankcron
  fi
}

do_display_setup()
{
  MODE_DISPLAY=$(get_config_var display $PMAINCONFIGFILE)
  Radio1=OFF
  Radio2=OFF
  Radio3=OFF
  Radio4=OFF
  Radio5=OFF
  Radio6=OFF
  Radio7=OFF
  Radio8=OFF
  case "$MODE_DISPLAY" in
  Tontec35)
    Radio1=ON
  ;;
  HDMITouch)
    Radio2=ON
  ;;
  Waveshare)
    Radio3=ON
  ;;
  WaveshareB)
    Radio4=ON
  ;;
  Waveshare4)
    Radio5=ON
  ;;
  Console)
    Radio6=ON
  ;;
  Element14_7)
    Radio7=ON
  ;;
  dfrobot5)
    Radio8=ON
  ;;
  *)
    Radio1=ON
  ;;		
  esac

  chdisplay=$(whiptail --title "$StrDisplaySetupTitle" --radiolist \
    "$StrDisplaySetupContext" 20 78 10 \
    "Tontec35" "$DisplaySetupTontec" $Radio1 \
    "HDMITouch" "$DisplaySetupHDMI" $Radio2 \
    "Waveshare" "$DisplaySetupRpiLCD" $Radio3 \
    "WaveshareB" "$DisplaySetupRpiBLCD" $Radio4 \
    "Waveshare4" "$DisplaySetupRpi4LCD" $Radio5 \
    "Console" "$DisplaySetupConsole" $Radio6 \
    "Element14_7" "Element 14 RPi 7 inch Display" $Radio7 \
    "dfrobot5" "DF Robot DFR0550 5 inch Display" $Radio8 \
 	 3>&2 2>&1 1>&3)

  if [ $? -eq 0 ]; then                     ## If the selection has changed

    ## This section modifies and replaces the end of /boot/config.txt
    ## to allow (only) the correct LCD drivers to be loaded at next boot

    ## Set constants for the amendment of /boot/config.txt
    PATHCONFIGS="/home/pi/rpidatv/scripts/configs"  ## Path to config files
    lead='^## Begin LCD Driver'               ## Marker for start of inserted text
    tail='^## End LCD Driver'                 ## Marker for end of inserted text
    CHANGEFILE="/boot/config.txt"             ## File requiring added text
    APPENDFILE=$PATHCONFIGS"/lcd_markers.txt" ## File containing both markers
    TRANSFILE=$PATHCONFIGS"/transfer.txt"     ## File used for transfer

    grep -q "$lead" "$CHANGEFILE"     ## Is the first marker already present?
    if [ $? -ne 0 ]; then
      sudo bash -c 'cat '$APPENDFILE' >> '$CHANGEFILE' '  ## If not append the markers
    fi

    case "$chdisplay" in              ## Select the correct driver text
      Tontec35)  INSERTFILE=$PATHCONFIGS"/tontec35.txt" ;;
      HDMITouch) INSERTFILE=$PATHCONFIGS"/hdmitouch.txt" ;;
      Waveshare) INSERTFILE=$PATHCONFIGS"/waveshare.txt" ;;
      WaveshareB) INSERTFILE=$PATHCONFIGS"/waveshareb.txt" ;;
      Waveshare4) INSERTFILE=$PATHCONFIGS"/waveshare.txt" ;;
      Console)   INSERTFILE=$PATHCONFIGS"/console.txt" ;;
      Element14_7)  INSERTFILE=$PATHCONFIGS"/element14_7.txt" ;;
      dfrobot5)  INSERTFILE=$PATHCONFIGS"/dfrobot5.txt" ;;
    esac

    ## Replace whatever is between the markers with the driver text
    sed -e "/$lead/,/$tail/{ /$lead/{p; r $INSERTFILE
	        }; /$tail/p; d }" $CHANGEFILE >> $TRANSFILE

    sudo cp "$TRANSFILE" "$CHANGEFILE"          ## Copy from the transfer file
    rm $TRANSFILE                               ## Delete the transfer file

    ## Set the correct touchscreen map for FreqShow
    sudo rm /etc/pointercal                     ## Delete the old file
    case "$chdisplay" in                        ## Insert the new file
      Tontec35)  sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      HDMITouch) sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      Waveshare) sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      WaveshareB) sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      Waveshare4) sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare4_pointercal /etc/pointercal ;;
      Console)   sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      Element14_7)  sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
      dfrobot5)  sudo cp /home/pi/rpidatv/scripts/configs/freqshow/waveshare_pointercal /etc/pointercal ;;
    esac

    set_config_var display "$chdisplay" $PMAINCONFIGFILE
  fi
}

##################### Execute here #########################################

do_autostart_setup
