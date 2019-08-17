#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

# Watch Apple Time Machine backups (especially for network volumes)
# should the volumes get stuck as Network volumes tend to do - force unmount when safe
# network volumes have been getting stuck for years - at least in my experience
# this script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
# This does handle multiple network volumes and odd timing conditions
# No privs needed.  Execcute as login item using TimeMachineMonitor.app
#
# to see TimeMachine and this monitor logging
# log stream --style syslog  --info --predicate '(senderImagePath contains[cd] "TimeMachine") || (eventMessage contains "TimeMachineMonitor")'

INTERVAL=10
READTIMEOUT=9
APP="TimeMachineMonitor"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
LOGFILTER='processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine"'
DO_FORCE_UNMOUNT=0
PIPE="/tmp/TMpipe.$$"
LOGGER() { /usr/bin/logger -s -p local0.info $APP: $1 ; }
if [ "$1" != "" ]; then DO_FORCE_UNMOUNT=1; fi

trap 'forceUnmount' SIGUSR1
trap 'LOGGER "End"; kill $LOGPID $SIGPID; /bin/rm -f $PIPE; exit 0' SIGQUIT SIGTERM SIGINT
trap 'Force $(( $DO_FORCE_UNMOUNT + 1 )) ; LOGGER "+1 FORCE=$DO_FORCE_UNMOUNT"' SIGUSR2
trap 'Force $(( $DO_FORCE_UNMOUNT - 1 )) ; LOGGER "-1 FORCE=$DO_FORCE_UNMOUNT"' SIGHUP
trap 'LOGGER "Status FORCE=$DO_FORCE_UNMOUNT"' SIGINFO

Force() { DO_FORCE_UNMOUNT=$1; }
forceUnmount() {
	if [ $DO_FORCE_UNMOUNT -ge 2 ]; then LOGGER "forceUnmount: FORCE=$DO_FORCE_UNMOUNT" ; fi
	if [ $DO_FORCE_UNMOUNT -ge 1 ]; then
                TMvols=( $TMvol.* )
		for vol in "${TMvols[@]}"; do
			if [ $DO_FORCE_UNMOUNT -ge 2 ]; then LOGGER "forceUnmount: Vol=$vol" ; fi
			if [ "$vol" != "$TMvol.$SNAP" -a "$vol" != "$TMvol.*" ]; then
				trytype=""
				try=$(/usr/sbin/diskutil unmountDisk "$vol")
				if [ $? -ne 0 ]; then
					trytype="force "
					try=$(/usr/sbin/diskutil unmountDisk force "$vol")
				fi
				LOGGER "$trytype$try"
			fi
		done
		if [ $DO_FORCE_UNMOUNT -le 2 ]; then Force 0; fi
	fi
}

# subshell signals parent to spark forceUnmount handling
{ set -e ; sleep $INTERVAL ; while (true) do sleep $INTERVAL ; kill -USR1 $$ 2>/dev/null ; done } &
SIGPID=$!	# save for later killing on exit
/usr/bin/mkfifo $PIPE # named pipe for asynch handling
/usr/bin/log stream --style syslog --info --predicate "$LOGFILTER" > $PIPE &
LOGPID=$!	# keep track for later killing on term
exec < $PIPE	# push named pipe to stdin here for while read loop below

LOGGER "Start"
while (true) do
	while read -t $READTIMEOUT -r logmsg 
	do
		case $logmsg in
		*'Attempting to mount '*)Force 0
					LOGGER "Looking for backup disk..." ;;
		*'Checking size of '*)	Force 0
					LOGGER "Preparing backup..." ;;
		*'Will copy ('*)	Force 0
					LOGGER "Backup starting..." ;;
		*'Completed snapshot:'*)Force 0
					LOGGER "Finishing backup..." ;;
		*'Starting post-backup'*)Force 0
					LOGGER "Cleaning up..." ;;
		*'Verifying backup '*)	Force 0
				 	LOGGER "Verify started" ;;
		*'Backup verification'*)Force 0
					LOGGER "Verify ended" ;;
		*'Backup completed'*) 	Force 0
					LOGGER "Backup completed" ;;
		*'Backup canceled'*)	Force 0
					LOGGER "Stopping..." ;;
		*'Cancellation timed out'*)	Force 1 ;;
		*"Failed to unmount '$TMvol."*) Force 1 ;;
		*"Unmounted '$TMvol."*)		Force 1 ;; # Force 1 to catch other vols still mounted
		esac
	done 
done

