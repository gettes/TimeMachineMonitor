#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
Vols="/Volumes/"
NETRE='^(.+) on (.+) \((.+),.*'
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }

[[ $* =~ "Open TimeMachineLog" ]] && /usr/bin/open -b org.gettes.TimeMachineLog
[[ $* =~ "Status: TimeMachineMonitor" ]] && /usr/bin/open -b org.gettes.TimeMachineMonitor
[[ $* =~ "TimeMachineMonitor on GitHub" ]] && /usr/bin/open "http://github.com/gettes/TimeMachineMonitor"

TMvols=( $Vols* )
TMmounted=0
IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
mntvols=( $(/sbin/mount -vt afpfs,smbfs,hfs,apfs,exfat) )
#mntvols=( $(/bin/cat ./mount.out) ) # for debugging
#TMvols=( $(/bin/cat ./vol.out) ) # for debugging
IFS=$IFSBAK

MonCount=$(/bin/ps axw | /usr/bin/grep TimeMachineMonitor.app/Contents/Resources/script | /usr/bin/grep -v /usr/bin/grep | /usr/bin/wc -l | /usr/bin/awk '{print $1}')
MonStatus="NOT Running" ; MonActive=""
[[ $MonCount -eq 2 ]] && MonStatus="Running" && MonActive="DISABLED|"
/bin/cat <<HERE
${MonActive}MENUITEMICON|AppIcon.icns|Status: TimeMachineMonitor is $MonStatus
MENUITEMICON|AppIcon.icns|Open TimeMachineLog
----
HERE
for vol in "${TMvols[@]}"; do
	ismntvol=0
	if [ ${#mntvols[@]} -gt 0 ]; then
		for cnt in $(seq 0 $((${#mntvols[@]} - 1))); do
			mntvol="${mntvols[$cnt]}"
			[[ $mntvol == "/" ]] && mntvol = "/Volumes/Macintosh HD"
			if [[ $mntvol =~ $NETRE ]]; then
				mntvol=${BASH_REMATCH[2]}
			fi
			#[[ $mntvol != "/" && $mntvol =~ ^$vol ]] && ismntvol=1 && break
			[[ $mntvol =~ ^$vol ]] && ismntvol=1 && break
		done
	fi
	TM="    "; TMmark=" -> "
	[[ $vol =~ "Time Machine Backups" ]] && TM=$TMmark && TMmounted=1
	[[ $vol =~ ^$TMvol && $ismntvol -eq 1 ]] && TM=$TMmark && TMmounted=1
	[[ $vol = "/Volumes/Recovery" ]] && TM=$TMmark && TMmounted=1
	[[ $vol =~ ^$TMvol && $ismntvol -eq 0 ]] && continue
	echo "DISABLED|$TM$vol"
done

if [ $TMmounted -eq 1 ]; then
/bin/cat <<HERE
----
DISABLED|
DISABLED|**** Time Machine appears to be active
DISABLED|
DISABLED|     DO NOT close your laptop or eject Time Machine devices
DISABLED|
DISABLED|     Wait for Time Machine to finish!
DISABLED|
HERE
else
/bin/cat <<HERE
----
DISABLED|  Time Machine doesn't appear to be running
DISABLED|  Should now be safe to eject Time Machine devices
DISABLED|    and/or close your laptop
HERE
fi

/bin/cat <<HERE
----
MENUITEMICON|AppIcon.icns|TimeMachineMonitor on GitHub
HERE

exit

cat <<HERE
----
SUBMENU|Title|Item1|Item2|Item3
HERE

