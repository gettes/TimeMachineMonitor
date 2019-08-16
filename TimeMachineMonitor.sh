#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

# Watch Apple Time Machine backups (especially for network volumes)
# should the volumes get stuck as Network volumes tend to do - force unmount when safe
# network volumes have been getting stuck for years - at least in my experience
# this script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
# This does handle multiple network volumes and odd timing conditions
# No privs needed.  Execcute as login item using TimeMachineMonitor.app

DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }
INTERVAL=5	# how often to look for stuck volumes
READTIMEOUT=5
APP="TimeMachineMonitor"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
LOGFILTER='processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine"'
DO_FORCE_UNMOUNT=0
PIPE="/tmp/TMpipe.$$"
if [ "$1" != "" ]; then
	DO_FORCE_UNMOUNT=1
fi

trap 'forceUnmount' SIGUSR1
trap 'echo "$(DATE) Ouch."; /bin/kill $LOGPID $SIGPID; /bin/rm -f $PIPE; exit' SIGQUIT SIGTERM SIGINT SIGILL SIGBUS SIGSEGV
trap 'Force 1; echo "HUP FORCE=$DO_FORCE_UNMOUNT"' SIGHUP

{ set -e
  sleep $INTERVAL
  while (true) do
	sleep $INTERVAL
	/bin/kill -USR1 $$ 2>/dev/null
  done } &
SIGPID=$!	# save for later killing on term

/usr/bin/mkfifo $PIPE # named pipe for asynch handling
/usr/bin/log stream --style syslog --info --predicate "$LOGFILTER" > $PIPE &
LOGPID=$!	# keep track for later killing on term
exec < $PIPE	# push named pipe to stdin here

Force() { DO_FORCE_UNMOUNT=$1; }
forceUnmount() {
	if [ $DO_FORCE_UNMOUNT -eq 1 ]; then
                TMvols=( $TMvol.* )
		for vol in "${TMvols[@]}"; do
			if [ "$vol" != "$TMvol.$SNAP" ]; then
				#echo "$(DATE) $APP: Force ($vol)"
				echo "$(DATE) $APP: Force `/usr/sbin/diskutil unmountDisk force \"$vol\"`"
			fi
		done
		Force 0
	fi
}

echo "$(DATE) $APP:$DO_FORCE_UNMOUNT Monitor Start"
while (true) do
	while read -t $READTIMEOUT -r line
	do
		case $line in
		*'Checking size of '*)	Force 0
					echo "$(DATE) $APP: Time Machine Starting..." ;;
		*'Backing up to '*)	Force 0
					echo "$(DATE) $APP: Backup Started" ;;
		*'Cancellation timed out'*)	Force 1
						echo "$(DATE) $APP: Timeout: Cancellation" ;;
		*'Verifying backup disk image'*) Force 0
						 echo "$(DATE) $APP: Verify Started" ;;
		*'Backup verification '*) Force 0
					  echo "$(DATE) $APP: Verify Ended" ;;
		*'Backup completed'*) 	Force 0
					echo "$(DATE) $APP: Backup Completed" ;;
		*'Backup canceled'*)	Force 0
					echo "$(DATE) $APP: Backup Cancelled" ;;
		*'Failed to unmount'*)	Force 1 ;;
		*'Failed to eject'*)	Force 1 ;;
		*'Ejected '*' from '*)	Force 0 ;;
		esac
	done 
done
