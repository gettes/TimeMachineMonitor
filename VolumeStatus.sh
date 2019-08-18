#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
Vols="/Volumes/"
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }

echo "DISABLED|Volumes mounted @ $(DATE)"
echo "----"
TMvols=( $Vols* )
TMmounted=0
for vol in "${TMvols[@]}"; do
	TM="    "
	[[ $vol =~ "Time Machine Backups" ]] && TM="TM: " && TMmounted=1
	[[ $vol =~ ^$TMvol ]] && TM="TM: " && TMmounted=1
	echo "DISABLED|$TM$vol"
done

echo "----"
if [ $TMmounted -eq 1 ]; then
cat <<HERE
DISABLED|**** Time Machine volumes still mounted
DISABLED|     DO NOT close laptop or disconnect Time Machine devices
DISABLED|
DISABLED|     Wait for Time Machine to finish!
HERE
else
cat <<HERE
DISABLED|  Time Machine doesn't appear to be running now
DISABLED|     It should be safe to close your laptop
DISABLED|     and/or disconnect Time Machine devices
HERE
fi

exit

cat <<HERE
----
MENUITEMICON|http://sveinbjorn.org/images/andlat.png|Or even a URL!
SUBMENU|Title|Item1|Item2|Item3
DISABLED|SUBMENU|Item1|Item4|Item5
HERE

