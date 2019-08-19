#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
Vols="/Volumes/"
NETRE='^(.+) on (.+) \((.+),.*'
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }

TMvols=( $Vols* )
TMmounted=0
IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
mntvols=( $(/sbin/mount -vt afpfs,smbfs,hfs,apfs,exfat) )
#mntvols=( $(/bin/cat ./mount.out) ) # for debugging
#TMvols=( $(/bin/cat ./vol.out) ) # for debugging
IFS=$IFSBAK

echo "DISABLED|TimeMachineStatus: Volumes mounted" # @ $(DATE)"
echo "----"
for vol in "${TMvols[@]}"; do
	ismntvol=0
	if [ ${#mntvols[@]} -gt 0 ]; then
		for cnt in $(seq 0 $((${#mntvols[@]} - 1))); do
			mntvol="${mntvols[$cnt]}"
			[[ $mntvol = "/" ]] && $mntvol = "/Volumes/Macintosh HD"
			if [[ $mntvol =~ $NETRE ]]; then
				mntvol=${BASH_REMATCH[2]}
			fi
			[[ $vol = $mntvol ]] && ismntvol=1
		done
	fi
	TM="    "
	[[ $vol =~ ^$TMvol.$SNAP ]] && TM="" # $SNAP vols are on local disk
	[[ $vol =~ "Time Machine Backups" ]] && TM="TM> " && TMmounted=1
	[[ $vol =~ ^$TMvol ]] && TM="TM> " && TMmounted=1
	[[ $vol = "/Volumes/Recovery" ]] && TM="TM> " && TMmounted=1
	echo "DISABLED|$TM$vol"
done

echo "----"
if [ $TMmounted -eq 1 ]; then
cat <<HERE
DISABLED|
DISABLED|**** Time Machine appears to be active
DISABLED|
DISABLED|     DO NOT close your laptop or eject Time Machine devices
DISABLED|
DISABLED|     Wait for Time Machine to finish!
DISABLED|
HERE
else
cat <<HERE
DISABLED|  Time Machine doesn't appear to be running
DISABLED|  Should now be safe to eject Time Machine devices
DISABLED|    and/or close your laptop
HERE
fi

exit

cat <<HERE
----
MENUITEMICON|http://sveinbjorn.org/images/andlat.png|Or even a URL!
SUBMENU|Title|Item1|Item2|Item3
DISABLED|SUBMENU|Item1|Item4|Item5
HERE

