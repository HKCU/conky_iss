#!/bin/sh
#
#  Script to launch Conky clock, disk and system displays
#  Allow a pause between each one to prevent the possibility of a segfault from occurring.
#

#  Set directory where the configuration files are and the Lua script is
export conky_conf_dir=$HOME/.conky_iss
cd $conky_conf_dir

#  Start the clock.  There is a 5-second delay before the clock is drawn
conky -c ./conky_clock.conf &

#  Wait for three seconds
sleep 3

#  Start the disk usage display.  There is a 5-second delay before the rings are drawn
conky -c ./conky_disk.conf &

#  Wait for three seconds
sleep 3

#  Start the system display.  This one renders immediately
conky -c ./conky_sys.conf &

#  done!
exit;
