#!/bin/bash

#if [ "$(id -u)" != "0" ]; then
#	echo "This script must be run as root" 1>&2
#	exit 1
#fi

echo "You will be prompted for the root password"

MAILNOTIFIER_HOME=/usr/local/mailnotifier
LAUNCH_FILE=com.jefflanza.mailnotifier.plist
PROG_DEST=$MAILNOTIFIER_HOME

sudo rm -rvf /usr/local/mailnotifier
rm -rvf ~/.mailnotifier

launchctl unload ~/Library/LaunchAgents/$LAUNCH_FILE
rm -v ~/Library/LaunchAgents/$LAUNCH_FILE

echo "Successfully Removed!"
