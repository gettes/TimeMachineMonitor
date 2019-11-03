#!/bin/bash

# Michael R Gettes, August, 2019

# Watch Apple Time Machine backups (especially for network volumes)
# should the volumes get stuck as Network volumes tend to do - force unmount when safe
# network volumes have been getting stuck for years - at least in my experience
# this script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
# This does handle multiple network volumes and odd timing conditions
# No privs needed.  Execcute as login item using TimeMachineMonitor.app
#

DEBUG=0
READTIMEOUT=5
OSX_VER=$(/usr/bin/sw_vers -productVersion)
APP="TimeMachineMonitor"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
TMvol2="/Volumes/.timemachine"
LOGFILTER='processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine"'
LOGCOMMAND="/usr/bin/log stream --style syslog --info --predicate"
DO_FORCE_UNMOUNT=0
PIPE=/tmp/TMpipe.$$
DISKUTIL="/usr/sbin/diskutil"
STATUSFILE="/tmp/.TimeMachineMonitor"
LOGGER() { /usr/bin/logger -s -p local0.info $APP: $1; echo "$(/bin/date -j -f '%a %b %d %T %Z %Y' "$(/bin/date)" '+%s') $1" >> $STATUSFILE ; }
NETRE='^(.+) on (.+) \((afpfs|smbfs),.*'
MNTRE='^(.+) on (.+) \(.+'
self=$$
NetworkMount=0
running=`: ; pid=$(bash -c 'echo $PPID'); /bin/ps ax | /usr/bin/grep "bash $0" | /usr/bin/egrep -v "grep|$self|$pid" | /usr/bin/awk '{print $1}'`

if [ -n "$1" ]; then		# set up debugging
	DEBUG=1
	DISKUTIL="echo"
	running=""
	READTIMEOUT=3
	LOGCOMMAND="/usr/bin/tail -f -n 100000000 $1"
	LOGFILTER="''"
fi

for pid in "$running"; do kill -TERM $pid 2>/dev/null; done
[[ $DEBUG -ne 0 ]] && echo "debugging DISKUTIL=$DISKUTIL"

trap 'forceUnmount' SIGUSR1
trap 'LOGGER "Caught SIGILL - Restarting" ; Restart' SIGILL
trap 'CleanUp ; exit 0' SIGTERM SIGHUP
trap 'Force $(( $DO_FORCE_UNMOUNT + 1 )) ; LOGGER "+1 FORCE=$DO_FORCE_UNMOUNT"' SIGUSR2
trap 'Force $(( $DO_FORCE_UNMOUNT - 1 )) ; LOGGER "-1 FORCE=$DO_FORCE_UNMOUNT"' SIGBUS
trap 'LOGGER "Status FORCE=$DO_FORCE_UNMOUNT"' SIGINFO

CleanUp() {
	trap - SIGCHLD; set +m; LOGGER "End `/bin/rm $PIPE 2>&1`"; kill $LOGPID 2>/dev/null; wait;
}
Restart() {
	CleanUp
	MonPIDS=$(/bin/ps axw | /usr/bin/egrep 'TimeMachineMonitor.app/Contents/MacOS/TimeMachineMonitor' | /usr/bin/grep -v /usr/bin/egrep | /usr/bin/awk '{print $1}')
	kill -TERM $MonPIDS
	trap - SIGTERM SIGHUP
	/usr/bin/open -b org.gettes.TimeMachineMonitor &
	exit 0
}
Force() { DO_FORCE_UNMOUNT=$1; [[ $DEBUG -ne 0 ]] && LOGGER "Force = $DO_FORCE_UNMOUNT" ; }
isNetwork() {
	NetworkMount=0
	IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
	netvols=($(/sbin/mount -vt smbfs,afpfs))  # TM vols are only on afp/smb network volumes
	IFS=$IFSBAK
	TMvols=( /Volumes/* $TMvol2/* )
	for vol in "${TMvols[@]}"; do
		[[ $DO_FORCE_UNMOUNT -ge 2 ]] && LOGGER "forceUnmount: Vol=$vol"
		if ( [[ $vol =~ ^$TMvol2.+ ]] || [[ $vol =~ ^$TMvol.+ ]] ) ; then	# 10.15
			isnetvol=0
			for cnt in $(seq 0 $((${#netvols[@]} - 1))); do
				[[ $cnt -lt 0 ]] && continue
				netvol="${netvols[$cnt]}"
				if [[ $netvol =~ $NETRE ]]; then
					mntvol=${BASH_REMATCH[2]}
				fi
				[[ $mntvol =~ ^$vol ]] && isnetvol=1 && vol=$mntvol
			done
			[[ $isnetvol -eq 0 ]] && continue # only try unmount on netvols
			NetworkMount=1
			[[ $DEBUG -eq 1 ]] && LOGGER "NetworkMount=$NetworkMount for $vol"
		fi
	done
}
forceUnmount() {
	[[ $DO_FORCE_UNMOUNT -eq 0 ]] && return 0
	IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
	netvols=($(/sbin/mount -vt smbfs,afpfs))  # TM vols are only on afp/smb network volumes
	snapvols=($(/sbin/mount -v))  # grab all vols to look for snapshot vols to dismount later
	IFS=$IFSBAK
	if [ $DO_FORCE_UNMOUNT -ge 2 ]; then LOGGER "forceUnmount: FORCE=$DO_FORCE_UNMOUNT" ; fi
	if [ $DO_FORCE_UNMOUNT -ge 1 ]; then
                TMvols=( /Volumes/* $TMvol2/* )
		for vol in "${TMvols[@]}"; do
			[[ $DO_FORCE_UNMOUNT -ge 2 ]] && LOGGER "forceUnmount: Vol=$vol"
			if ( [[ $vol =~ ^$TMvol2.+ ]] || [[ $vol =~ ^$TMvol.+ ]] ) ; then	# 10.15
				isnetvol=0
				for cnt in $(seq 0 $((${#netvols[@]} - 1))); do
					[[ $cnt -lt 0 ]] && continue
					netvol="${netvols[$cnt]}"
					if [[ $netvol =~ $NETRE ]]; then
						mntvol=${BASH_REMATCH[2]}
					fi
					[[ $mntvol =~ ^$vol ]] && isnetvol=1 && vol=$mntvol
				done
				[[ $isnetvol -eq 0 ]] && continue # only try unmount on netvols
				trytype="($isnetvol) "
				try=$($DISKUTIL unmountDisk force "/Volumes/Time Machine Backups")
				if [ -n "$try" ]; then LOGGER "unmount /Volumes/Time Machine Backups: $try" ; fi
				try=$($DISKUTIL unmountDisk "$vol")
				if [ $? -ne 0 ]; then
					trytype="force${trytype}"
					try=$($DISKUTIL unmountDisk force "$vol")
				fi
				if [ -n "$try" ]; then LOGGER "${trytype}${try}" ; fi
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
		if [ $DO_FORCE_UNMOUNT -le 2 ]; then 
			Force 0; LOGGER "Backup ended."; 
			DONE_ALMOST=0
		fi
	fi
}
SignalHandler() {
	kill -0 $LOGPID 2>/dev/null
	if [ $? -ne 0 ]; then 
		LOGGER "log ($LOGPID) dead! (DEBUG=$DEBUG $LOGCOMMAND $LOGFILTER)"
		kill -0 $LOGPID 
		wait $LOGPID
		[[ $DEBUG -eq 0 ]] && CleanUp; exit && startLogstream
	fi
}
startLogstream() {
	/bin/rm -f $PIPE
	/usr/bin/mkfifo $PIPE # named pipe for asynch handling
	$LOGCOMMAND "$LOGFILTER" > $PIPE &
	LOGPID=$!	# keep track for later killing on term
	exec < $PIPE	# push named pipe to stdin here for while read loop below
}

startLogstream

#set -m
#trap 'SignalHandler' SIGCHLD

LOGGER "Start ($self) $OSX_VER"
[[ $DEBUG -ne 0 ]] && Force 2
DONE_ALMOST=0
while (true) do
	while read -t $READTIMEOUT -r logmsg 
	do
		case $logmsg in
		*'Starting '*'backup')	Force 0
					/bin/rm -f $STATUSFILE
					LOGGER "Started" ;;
		*'Attempting to mount '*)Force 0
					LOGGER "Looking for backup disk..." ;;
		*'Checking for runtime '*)Force 0
					LOGGER "Preparing backup..." ;;
		*' Backing up to '*)	Force 0
					isNetwork
					;;
		*'Will copy ('*)	Force 0
					LOGGER "Backing up..." ;;
		*'need to be backed up from all sources'*) Force 0 # MacOS 10.15
					LOGGER "Backing up..." ;;
		*'Completed snapshot:'*)Force 0
					LOGGER "Finishing backup..." ;;
		*'Completed backup:'*)Force 0 # MacOS 10.15
					LOGGER "Finishing backup..." ;;
		*'Starting post-backup'*)Force 0
					LOGGER "Cleaning up..." ;;
		*'Finished copying recovery system'*)Force 0 # MacOS 10.15
					LOGGER "Cleaning up..." ;;
		*'Verifying backup '*)	Force 0
				 	LOGGER "Verify started" ;;
		*'Backup verification'*)Force 0
					LOGGER "Verify ended" ;;
		*'Backup completed'*) 	Force 0
					DONE_ALMOST=1
					[[ $NetworkMount -eq 1 ]] && LOGGER "Backup almost completed"
					[[ $NetworkMount -eq 0 ]] && Force 1
					;;
		*'Backup canceled'*)	Force 0
					LOGGER "Stopping..."
					[[ "$OSX_VER" =~ ^10\.15 ]] && Force 1
					;;
		*'Backup cancel was requested.'*) Force 0
					LOGGER "Stopping..." ;;
		*' Thinning '*) 	Force 0
					LOGGER "Thinning Backup Volume..." ;;
		*'Cancellation timed out'*)	Force 1 ;;
 		*'The backup disk could not be found.'*)Force 0 
					LOGGER "Backup disk not found." ;;
		*"Failed to unmount '$TMvol."*) Force 1
					LOGGER "Backup ending... monitor cleanup"
					;;
		*"Failed to unmount '$TMvol2"*) Force 1 
					LOGGER "Backup ending... monitor cleanup"
					[[ $DEBUG -ne 0 ]] && Force 2
					;; # MacOS 10.15
		*"Unmounted '$TMvol."*)		Force 1 ;; # MacOS 10.14
		*"Unmounted '$TMvol2."*)	Force 1 ;; # MacOS 10.15
		*"Ejected Time Machine network volume"*)Force 1 ;; # MacOS 10.13
		*"Ejected disk"*) 	[[ $DONE_ALMOST -eq 1 ]] && Force 1
					;;
		esac
	done 
	forceUnmount
	SignalHandler

	#echo "TIMEOUT: $?"
	#/usr/bin/tmutil status | grep DestinationID
	#echo "rc: $?"
done

