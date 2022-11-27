#!/bin/bash

# Portsdown 4 NG Install by davecrump on 20221124

BuildLogMsg() {
  if [[ "$1" == "0" ]]; then
    echo $(date -u) "Build Success " "$2" | sudo tee -a /home/pi/p4ng_initial_build_log.txt  > /dev/null
  else
    echo $(date -u) "Build Fail    " "$2" | sudo tee -a /home/pi/p4ng_initial_build_log.txt  > /dev/null
  fi
}

# Create first entry for the build and update logs
echo $(date -u) "New Build started" | sudo tee -a /home/pi/p4ng_initial_build_log.txt  > /dev/null
sudo chown pi:pi /home/pi/p4ng_initial_build_log.txt

# Check current user
whoami | grep -q pi
if [ $? != 0 ]; then
  echo "Install must be performed as user pi"
  BuildLogMsg "1" "Exiting, not user pi"
  exit
fi

# Check Correct Raspberry Pi OS Version (Bullseye)
lsb_release -a | grep -q bullseye
if [ $? != 0 ]; then
  echo
  echo "The Repeater Controller requires the Raspberry Pi OS Bullseye"
  echo "You may have used buster, which is the previous version, but not suitable for this build"
  echo 
  echo "Press any key to exit"
  read -n 1
  printf "\n"
  if [[ "$REPLY" = "d" || "$REPLY" = "D" ]]; then  # Allow to proceed for development
    echo "Continuing build......"
    BuildLogMsg "0" "Warning, NOT BULLSEYE OS"
  else
    BuildLogMsg "1" "Exiting, NOT BULLSEYE OS"
    exit
  fi
fi

if [ "$1" == "-d" ]; then
  GIT_SRC="davecrump";
  echo
  echo "-----------------------------------------------------------"
  echo "----- Installing development version of Portsdown 4 NG-----"
  echo "-----------------------------------------------------------"
  BuildLogMsg "0" "Installing Dev Version"
elif [ "$1" == "-u" -a ! -z "$2" ]; then
  GIT_SRC="$2"
  echo
  echo "WARNING: Installing ${GIT_SRC} development version, press enter to continue or 'q' to quit."
  read -n1 -r -s key;
  if [[ $key == q ]]; then
    exit 1;
  fi
  echo "ok!";
  BuildLogMsg "0" "Installing ${GIT_SRC} Version"
else
  GIT_SRC="britishamateurtelevisionclub";
  echo
  echo "----------------------------------------------------------------"
  echo "----- Installing BATC Production version of Portsdown 4 NG -----"
  echo "----------------------------------------------------------------"
  BuildLogMsg "0" "Installing Production Version"
fi

# Update the package manager
echo
echo "------------------------------------"
echo "----- Updating Package Manager -----"
echo "------------------------------------"
sudo dpkg --configure -a
SUCCESS=$?; BuildLogMsg $SUCCESS "dpkg configure"
sudo apt-get update --allow-releaseinfo-change
SUCCESS=$?; BuildLogMsg $SUCCESS "apt-get update"

# Uninstall the apt-listchanges package to allow silent install of ca certificates (201704030)
# http://unix.stackexchange.com/questions/124468/how-do-i-resolve-an-apparent-hanging-update-process
sudo apt-get -y remove apt-listchanges
SUCCESS=$?; BuildLogMsg $SUCCESS "remove apt-listchanges"

# Upgrade the distribution
echo
echo "-----------------------------------"
echo "----- Performing dist-upgrade -----"
echo "-----------------------------------"
sudo apt-get -y dist-upgrade
SUCCESS=$?; BuildLogMsg $SUCCESS "dist-upgrade"

# Install the packages that we need
echo
echo "-------------------------------"
echo "----- Installing Packages -----"
echo "-------------------------------"

sudo apt-get -y install git
SUCCESS=$?; BuildLogMsg $SUCCESS "git install"

sudo apt-get -y install cmake
SUCCESS=$?; BuildLogMsg $SUCCESS "cmake install"

sudo apt-get -y install libusb-1.0-0-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libusb-1.0-0-dev install"

sudo apt-get -y install libfftw3-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libfftw3-dev install"

sudo apt-get -y install libxcb-shape0
SUCCESS=$?; BuildLogMsg $SUCCESS "libxcb-shape0 install"

sudo apt-get -y install vlc
SUCCESS=$?; BuildLogMsg $SUCCESS "vlc install"

sudo apt-get -y install ffmpeg
SUCCESS=$?; BuildLogMsg $SUCCESS "ffmpeg install"

sudo apt-get -y install pigpio
SUCCESS=$?; BuildLogMsg $SUCCESS "pigpio install"
cd /home/pi  # This install leaves at root

echo
echo "------------------------------------------"
echo "----- Installing libiio dependencies -----"
echo "------------------------------------------"

sudo apt-get -y install libxml2-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libxml2-dev install"

sudo apt-get -y install bison
SUCCESS=$?; BuildLogMsg $SUCCESS "bison install"

sudo apt-get -y install flex
SUCCESS=$?; BuildLogMsg $SUCCESS "flex install"

sudo apt-get -y install libcdk5-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libcdk5-dev install"

sudo apt-get -y install libaio-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libaio-dev install"

sudo apt-get -y install libavahi-client-dev
SUCCESS=$?; BuildLogMsg $SUCCESS "libavahi-client-dev install"

echo
echo "------------------------------------------"
echo "----- Setting up for captured images -----"
echo "------------------------------------------"

# Amend /etc/fstab to create a tmpfs drive at ~/tmp for multiple images (201708150)
sudo sed -i '4itmpfs           /home/pi/tmp    tmpfs   defaults,noatime,nosuid,size=10m  0  0' /etc/fstab
SUCCESS=$?; BuildLogMsg $SUCCESS "Created ~/tmp ramdrive"

# Create a ~/snaps folder for captured images (201708150)
mkdir /home/pi/snaps
SUCCESS=$?; BuildLogMsg $SUCCESS "Created ~/snaps folder"

# Set the image index number to 0 (201708150)
echo "0" > /home/pi/snaps/snap_index.txt

# Install LimeSuite 22.09.1 as at 24 Nov 22
# Commit 475964c80459f338de337524dd9085d87cba1c9e
echo
echo "----------------------------------------"
echo "----- Installing LimeSuite 22.09.1 -----"
echo "----------------------------------------"
wget https://github.com/myriadrf/LimeSuite/archive/475964c80459f338de337524dd9085d87cba1c9e.zip -O master.zip
SUCCESS=$?; BuildLogMsg $SUCCESS "LimeSuite Download"
unzip -o master.zip
cp -f -r LimeSuite-475964c80459f338de337524dd9085d87cba1c9e LimeSuite
rm -rf LimeSuite-475964c80459f338de337524dd9085d87cba1c9e
rm master.zip

# Compile LimeSuite
cd LimeSuite/
mkdir dirbuild
cd dirbuild/
cmake ../
SUCCESS=$?; BuildLogMsg $SUCCESS "LimeSuite cmake"
make
SUCCESS=$?; BuildLogMsg $SUCCESS "LimeSuite make"
sudo make install
sudo ldconfig
cd /home/pi

# Install udev rules for LimeSuite
cd LimeSuite/udev-rules
chmod +x install.sh
sudo /home/pi/LimeSuite/udev-rules/install.sh
cd /home/pi	

# Record the LimeSuite Version	
echo "475964c" >/home/pi/LimeSuite/commit_tag.txt

# Download the LimeSDR Mini firmware/gateware versions

echo
echo "------------------------------------------------------"
echo "----- Downloading LimeSDR Mini Firmware versions -----"
echo "------------------------------------------------------"

# Current Version from LimeSuite 20.10 
mkdir -p /home/pi/.local/share/LimeSuite/images/20.10/
wget https://downloads.myriadrf.org/project/limesuite/20.10/LimeSDR-Mini_HW_1.2_r1.30.rpd -O \
               /home/pi/.local/share/LimeSuite/images/20.10/LimeSDR-Mini_HW_1.2_r1.30.rpd
SUCCESS=$?; BuildLogMsg $SUCCESS "LimeMini Firmware 1.30 Download"

# DVB-S/S2 Version
mkdir -p /home/pi/.local/share/LimeSuite/images/v0.3
wget https://github.com/natsfr/LimeSDR_DVBSGateware/releases/download/v0.3/LimeSDR-Mini_lms7_trx_HW_1.2_auto.rpd -O \
 /home/pi/.local/share/LimeSuite/images/v0.3/LimeSDR-Mini_lms7_trx_HW_1.2_auto.rpd
SUCCESS=$?; BuildLogMsg $SUCCESS "LimeMini DVB Firmware Download"

echo
echo "-------------------------------------------"
echo "----- Installing libiio for Pluto SDR -----"
echo "-------------------------------------------"

# Install libiio for Pluto SigGen (and Langstone)
cd /home/pi
git clone https://github.com/analogdevicesinc/libiio.git
SUCCESS=$?; BuildLogMsg $SUCCESS "libiio git clone"
cd libiio
cmake ./
SUCCESS=$?; BuildLogMsg $SUCCESS "libiio cmake"
make all
SUCCESS=$?; BuildLogMsg $SUCCESS "libiio make"
sudo make install
cd /home/pi

# Download the previously selected version of Portsdown 4 NG
echo
echo "-----------------------------------------------"
echo "----- Downloading Portsdown 4 NG Software -----"
echo "-----------------------------------------------"
wget https://github.com/${GIT_SRC}/portsdown4ng/archive/main.zip
SUCCESS=$?; BuildLogMsg $SUCCESS "Portsdown 4 NG GitHub download"
# Unzip the portsdown software and copy to the Pi
unzip -o main.zip
mv portsdown4ng-main portsdown
rm main.zip
cd /home/pi

mkdir -p /home/pi/portsdown/bin   # May not be in download

# Install limesdr_toolbox
echo
echo "--------------------------------------"
echo "----- Installing LimeSDR Toolbox -----"
echo "--------------------------------------"
cd /home/pi/portsdown/src/limesdr_toolbox/libdvbmod/libdvbmod
make
SUCCESS=$?; BuildLogMsg $SUCCESS "libdvbmod make"
cd ../DvbTsToIQ/
make
SUCCESS=$?; BuildLogMsg $SUCCESS "dvb2iq make"
cp dvb2iq /home/pi/portsdown/bin/
cd /home/pi/portsdown/src/limesdr_toolbox/
make 
SUCCESS=$?; BuildLogMsg $SUCCESS "limesdr_toolbox make"
cp limesdr_send /home/pi/portsdown/bin/
cp limesdr_dump /home/pi/portsdown/bin/
cp limesdr_stopchannel /home/pi/portsdown/bin/
cp limesdr_forward /home/pi/portsdown/bin/
make dvb
SUCCESS=$?; BuildLogMsg $SUCCESS "limesdr_dvb make"
cp limesdr_dvb /home/pi/portsdown/bin/
cd /home/pi

# Set auto login to command line.
sudo raspi-config nonint do_boot_behaviour B2

# Modify .bashrc to run startup script on ssh logon
echo if test -z \"\$SSH_CLIENT\" >> ~/.bashrc 
echo then >> ~/.bashrc
echo "  source /home/pi/portsdown/scripts/startup.sh" >> ~/.bashrc
echo fi >> ~/.bashrc

# Record Version Number
head -c 9 /home/pi/portsdown/version_history.txt > /home/pi/portsdown/installed_version.txt
echo -e "\n" >> /home/pi/portsdown/installed_version.txt
head -c 9 /home/pi/portsdown/version_history.txt > /home/pi/p4ng_initial_build_log.txt
echo -e "Install script finished\n" >> /home/pi/p4ng_initial_build_log.txt

cd /home/pi

echo
echo "SD Card Serial:"
cat /sys/block/mmcblk0/device/cid

# Reboot
echo
echo "--------------------------------"
echo "----- Complete.  Rebooting -----"
echo "--------------------------------"
sleep 1

sudo reboot now
exit
