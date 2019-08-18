#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
Vols="/Volumes/"
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }

echo "Volumes mounted @ $(DATE)"
echo " "
TMvols=( $Vols* )
TMmounted=0
for vol in "${TMvols[@]}"; do
	TM="        "
	[[ $vol =~ "Time Machine Backups" ]] && TM="TM vol: " && TMmounted=1
	[[ $vol =~ ^$TMvol ]] && TM="TM vol: " && TMmounted=1
	echo "$TM$vol"
done

if [ $TMmounted -eq 1 ]; then
	echo " "
	echo "**** Time Machine volumes still mounted"
	echo "     DO NOT close laptop or disconnect Time Machine devices"
	echo " "
	echo "     Wait for Time Machine to finish"
	echo " "
else
	echo " "
	echo "  Time Machine doesn't appear to be running now"
	echo "     It appears to be safe to close your laptop"
	echo "     and/or disconnect Time Machine devices"
	echo " "
fi
