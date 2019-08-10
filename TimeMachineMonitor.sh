#!/bin/bash

#
# Michael R Gettes, gettes@gmail.com, August, 2019

# Watch Apple Time Machine backups (especially for network volumes)
# should the volumes get stuck as Network volumes tend to do - force unmount when safe
# network volumes have been getting stuck for years - at least in my experience
# this script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
# This does handle multiple network volumes.

DELAY=30 	# number of seconds after backup completes to see if volume is still there
INTERVAL=10	# a slight deley between force unmount

APP="TimeMachineMonitor"
SNAP="localsnapshots"
LOGFILTER='processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine"'

echo "`/bin/date` $APP: Start"

while (true) do
	/usr/bin/log stream --style syslog --info --predicate "$LOGFILTER" | while read line
	do
		case $line in
		*'Starting automatic backup') echo "`/bin/date` $APP: Time Machine Started (automatic)" ;;
		*'Starting manual backup') echo "`/bin/date` $APP: Time Machine Started (manual)" ;;
		*'Starting post-backup thinning') echo "`/bin/date` $APP: Thinning (post)" ;;
		*'Backing up to '*) echo "`/bin/date` $APP: A Backup Started" ;;
		*'Mounted stable snapshot:'*) echo "`/bin/date` $APP: Snapshot mounted" ;;
		*'Completed snapshot:'*) echo "`/bin/date` $APP: Snapshot completed" ;;
		*'Backup completed'*) echo "`/bin/date` $APP: Completed" ; break ;;
		esac
	done
	sleep $DELAY
	TMvols=`/bin/ls /Volumes/ | /usr/bin/egrep com.apple.TimeMachine.* | /usr/bin/egrep -v $SNAP | /usr/bin/tr -d "\\n" `
	if [ -n "$TMvols" ]; then
		for vol in "$TMvols"
		do
			echo "`/bin/date` $APP: CLEANUP: diskutil unmountDisk force /Volumes/$vol"
			/usr/sbin/diskutil unmountDisk force "/Volumes/$vol"
		done
		sleep $INTERVAL
	fi
	#TMbu=`/bin/ls -d /Volumes/Time\ Machine\ Backups* 2>/dev/null | /usr/bin/tr "\\n" ' ' `
	#TMvols=`/bin/ls /Volumes/ | /usr/bin/egrep com.apple.TimeMachine.* | /usr/bin/egrep -v $SNAP | /usr/bin/tr "\\n" ' ' `
	#echo "`/bin/date` $APP: END Vols= ( $TMbu) ( $TMvols)"
	echo "`/bin/date` $APP: Looking for next backup"
done

