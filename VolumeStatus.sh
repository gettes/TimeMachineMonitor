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
	echo "Time Machine volumes still mounted"
	echo "     DO NOT close laptop or disconnect Time Machine volumes"
	echo " "
fi
