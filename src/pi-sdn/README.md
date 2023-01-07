# pi-sdn

## Usage

Install wiringpi (required for gpio setup since ~Q4/2016).

    sudo apt-get install wiringpi

Run the following command, or download the compiled binary from the Releases tab and copy it to the home directory.

    wget 'https://github.com/philcrump/pi-sdn/releases/download/v1.1/pi-sdn' -O /home/pi/pi-sdn

Make sure that the file is executable.

    chmod +x /home/pi/pi-sdn

Add the following line to /etc/rc.local, before 'exit 0'.

    sudo /home/pi/pi-sdn n x > /dev/null 2>&1 &

*   Substitute 'n' for the WiringPi GPIO Number on which pi-sdn will trigger shutdown when it sees a Rising Edge.
    *    This GPIO will be configured with the BCM's internal pulldown resistor (~50KOhm), so a button can be directly connected between this pin and 3.3V.
        *    In EM-heavy environments, such as radio transmitters, a stronger external pulldown resistor (eg. 1KOhm) can be required to prevent unwanted triggering.
*   Substitue or remove 'x' for the optional WiringPi GPIO Number on which pi-sdn will output constant 3.3V during runtime.
    *    A complete shutdown can be detected by a transition to High-Z, or lack of sourced current, on this pin.
    *    An external pull-down resistor or LED can be used to cause a Falling Edge on complete shutdown.

### GPIO Number

pi-sdn uses the WiringPi pin numbers (0-20).

The pinout can be found at http://wiringpi.com/pins/

## Compile from source

(Only required if you wish to make changes)

Clone the git repository

    cd ~/
    git clone https://github.com/philcrump/pi-sdn.git pi-sdn-git/
    cd pi-sdn-git/

Compile and install wiringPi with static headers

    git submodule update --init
    cd wiringPi/
    ./build
    cd wiringPi/
    make static
    sudo make install-static

Compile pi-sdn

    cd ~/pi-sdn-git/
    make
    cp pi-sdn ~/pi-sdn

## Authors

Copyright (c) 2015 Phil Crump <phil@philcrump.co.uk>

MIT License

