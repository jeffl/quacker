#!/bin/bash

#if [ "$(id -u)" != "0" ]; then
#	echo "This script must be run as root" 1>&2
	#exit 1
#fi

echo "You will be prompted for the root password"

MAILNOTIFIER_HOME=/usr/local/mailnotifier
LAUNCH_FILE=com.jefflanza.mailnotifier.plist
PROG_DEST=$MAILNOTIFIER_HOME

sudo mkdir -v $STORE_DEST $PROG_DEST $PROG_DEST/assets $PROG_DEST/extras $PROG_DEST/lib $PROG_DEST/bin

sudo cp -rv assets/ $PROG_DEST/assets/
sudo cp -rv lib/ $PROG_DEST/lib/
sudo cp -rv bin/ $PROG_DEST/bin/
sudo cp -rv extras/ $PROG_DEST/extras/

#echo "Adding program path to bash_profile"
#echo "export MAILNOTIFIER_HOME=$MAILNOTIFIER_HOME" >> ~/.bash_profile

mkdir -v ~/.mailnotifier

#source ~/.bash_profile

cp -prv extras/$LAUNCH_FILE ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/$LAUNCH_FILE

echo "Files Copied, now you must edit your config!"
