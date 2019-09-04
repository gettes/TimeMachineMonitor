#!/bin/bash

# Michael R Gettes, August, 2019

# Watch Apple Time Machine backups (especially for network volumes)
# should the volumes get stuck as Network volumes tend to do - force unmount when safe
# network volumes have been getting stuck for years - at least in my experience
# this script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
# This does handle multiple network volumes and odd timing conditions
# No privs needed.  Execcute as login item using TimeMachineMonitor.app
#
# to see TimeMachine and this monitor logging
# log stream --style syslog  --info --predicate '(processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine") || (eventMessage contains "TimeMachineMonitor:")'

INTERVAL=10
READTIMEOUT=30
APP="TimeMachineMonitor"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
LOGFILTER='processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine"'
DO_FORCE_UNMOUNT=0
PIPE=/tmp/TMpipe.$$
DISKUTIL="/usr/sbin/diskutil"
#EP='/bin/date -j -f "%a %b %d %T %Z %Y" $(/bin/date) "+%s"'
STATUSFILE="/tmp/.$APP"
LOGGER() { /usr/bin/logger -s -p local0.info $APP: $1; echo "$(/bin/date -j -f '%a %b %d %T %Z %Y' "$(/bin/date)" '+%s') $1" > $STATUSFILE ; }
NETRE='^(.+) on (.+) \((afpfs|smbfs),.*'
MNTRE='^(.+) on (.+) \(.+'
if [ "$1" != "" ]; then DO_FORCE_UNMOUNT=1; fi
self=$$
running=`: ; pid=$(bash -c 'echo $PPID'); /bin/ps ax | /usr/bin/grep "bash $0" | /usr/bin/egrep -v "grep|$self|$pid" | /usr/bin/awk '{print $1}'`
for pid in "$running"; do kill $pid 2>/dev/null; done

trap 'forceUnmount' SIGUSR1
trap 'trap - SIGCHLD; set +m; LOGGER "End `/bin/rm $PIPE 2>&1`"; kill $LOGPID $SIGPID; wait; exit 0' SIGQUIT SIGTERM SIGINT SIGHUP
trap 'Force $(( $DO_FORCE_UNMOUNT + 1 )) ; LOGGER "+1 FORCE=$DO_FORCE_UNMOUNT"' SIGUSR2
trap 'Force $(( $DO_FORCE_UNMOUNT - 1 )) ; LOGGER "-1 FORCE=$DO_FORCE_UNMOUNT"' SIGBUS
trap 'LOGGER "Status FORCE=$DO_FORCE_UNMOUNT"' SIGINFO

Force() { DO_FORCE_UNMOUNT=$1; }
forceUnmount() {
	IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
	netvols=($(/sbin/mount -vt smbfs,afpfs))  # TM vols are only on afp/smb network volumes
	snapvols=($(/sbin/mount -v))  # grab all vols to look for snapshot vols to dismount later
	IFS=$IFSBAK
	if [ $DO_FORCE_UNMOUNT -ge 2 ]; then LOGGER "forceUnmount: FORCE=$DO_FORCE_UNMOUNT" ; fi
	if [ $DO_FORCE_UNMOUNT -ge 1 ]; then
                TMvols=( $TMvol.* )
		for vol in "${TMvols[@]}"; do
			if [ $DO_FORCE_UNMOUNT -ge 2 ]; then LOGGER "forceUnmount: Vol=$vol" ; fi
			if [ "$vol" != "$TMvol.$SNAP" -a "$vol" != "$TMvol.*" ]; then
				isnetvol=0
				for cnt in $(seq 0 $((${#netvols[@]} - 1))); do
					netvol="${netvols[$cnt]}"
					if [[ $netvol =~ $NETRE ]]; then
						mntvol=${BASH_REMATCH[2]}
					fi
					[[ $vol = $mntvol ]] && isnetvol=1
				done
				[[ $isnetvol -eq 0 ]] && continue # only try unmount on netvols
				trytype="netvol=$isnetvol "
				$DISKUTIL unmountDisk force "/Volumes/Time Machine Backups"
				try=$($DISKUTIL unmountDisk "$vol")
				if [ $? -ne 0 ]; then
					trytype="${trytype}force "
					try=$($DISKUTIL unmountDisk force "$vol")
				fi
				LOGGER "${trytype}${try}"
			fi
		done
		# now look for any mounts remaining for snapshots
		for cnt in $(seq 0 $((${#snapvols[@]} - 1))); do
			vol="${snapvols[$cnt]}"
			if [[ $vol =~ $MNTRE ]]; then
				mntvol=${BASH_REMATCH[2]}
			else
				continue
			fi
			[[ ! $mntvol =~ ^$TMvol\.$SNAP ]] && continue
			trytype="snapvol: "
			try=$($DISKUTIL unmountDisk "$mntvol")
			if [ $? -ne 0 ]; then
				trytype="${trytype}force "
				try=$($DISKUTIL unmountDisk force "$mntvol")
			fi
			LOGGER "${trytype}${try}"
		done
		if [ $DO_FORCE_UNMOUNT -le 2 ]; then Force 0; LOGGER "Backup ended."; fi
	fi
}
childSignalHandler() {
	kill -0 $SIGPID 2>/dev/null
	#if [ $? -eq 0 ]; then echo "sig ($SIGPID) is alive!"; else echo "sig ($SIGPID) dead!"; startSignaler; fi
	if [ $? -ne 0 ]; then echo "sig ($SIGPID) dead!"; startSignaler; fi
	kill -0 $LOGPID 2>/dev/null
	#if [ $? -eq 0 ]; then echo "log ($LOGPID) is alive!"; else echo "log ($LOGPID) dead!"; startLogstream; fi
	if [ $? -ne 0 ]; then echo "log ($LOGPID) dead!"; startLogstream; fi
}
startSignaler() {
	# subshell signals parent to spark forceUnmount handling
	{ set -e ; sleep $INTERVAL ; while (true) do sleep $INTERVAL ; kill -USR1 $$ 2>/dev/null ; done } &
	SIGPID=$!	# save for later killing on exit
}
startLogstream() {
	/bin/rm -f $PIPE
	/usr/bin/mkfifo $PIPE # named pipe for asynch handling
	/usr/bin/log stream --style syslog --info --predicate "$LOGFILTER" > $PIPE &
	LOGPID=$!	# keep track for later killing on term
	exec < $PIPE	# push named pipe to stdin here for while read loop below
}

startSignaler
startLogstream

set -m
trap 'childSignalHandler' SIGCHLD

LOGGER "Start"
while (true) do
	while read -t $READTIMEOUT -r logmsg 
	do
		case $logmsg in
		*'Attempting to mount '*)Force 0
					LOGGER "Looking for backup disk..." ;;
		*'Checking for runtime '*)Force 0
					LOGGER "Preparing backup..." ;;
		*'Will copy ('*)	Force 0
					LOGGER "Backing up..." ;;
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
		*'Failed to unmount snapshot:'*)LOGGER "Failure unmount snapshot" ;;
		*"Failed to unmount '$TMvol."*) Force 1 ;;
		*"Unmounted '$TMvol."*)		Force 1 ;; # MacOS 10.14
		*"Ejected Time Machine network volume"*)Force 1 ;; # MacOS 10.13
		esac
	done 
done

