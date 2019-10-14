#!/bin/bash

# Michael R Gettes, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
TMvol2="/Volumes/.timemachine"
Vols="/Volumes/* /Volumes/.timemachine/*"
NETRE='^(.+) on (.+) \((.+),.*'
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }
STATUSFILE=/tmp/.TimeMachineMonitor
MonPIDS=$(/bin/ps axw | /usr/bin/egrep 'TimeMachineMonitor.app/Contents/Resources/script|TimeMachineMonitor.app/Contents/MacOS/TimeMachineMonitor' | /usr/bin/grep -v /usr/bin/egrep | /usr/bin/awk '{print $1}')

RemoveLoginItems() {
scriptFile=/tmp/ascript.$$.scpt
script=$(/bin/cat <<'HERE'
tell application "Finder"
	try
		tell application "System Events" to delete login item "TimeMachineMonitor"
	end try
	try
		tell application "System Events" to delete login item "TimeMachineStatus"
	end try
	tell application "System Preferences"
		activate
		set the current pane to pane "com.apple.preferences.users"
		reveal anchor "startupItemsPref" of current pane
	end tell
end tell
HERE
)
echo "$script" > $scriptFile
/usr/bin/osascript $scriptFile
/bin/rm -f $scriptFile
}

InstallLoginItems() {
scriptFile=/tmp/ascript.$$.scpt
script=$(/bin/cat <<'HERE'
tell application "Finder"
	try
		tell application "System Events" to delete login item "TimeMachineMonitor"
	end try
	try
		set p to POSIX path of ((application file id "org.gettes.TimeMachineMonitor") as alias)
		tell application "System Events" to make login item at end with properties {name:"TimeMachineMonitor", path:p, hidden:true}
	end try
	try
		tell application "System Events" to delete login item "TimeMachineStatus"
	end try
	try
		set p to POSIX path of ((application file id "org.gettes.TimeMachineStatus") as alias)
		tell application "System Events" to make login item at end with properties {name:"TimeMachineStatus", path:p, hidden:true}
	end try
	tell application "System Preferences"
		activate
		set the current pane to pane "com.apple.preferences.users"
		reveal anchor "startupItemsPref" of current pane
	end tell
end tell
HERE
)
echo "$script" > $scriptFile
/usr/bin/osascript $scriptFile
/bin/rm -f $scriptFile
}

e1='^EJECT\: (.*)$'
e2='^FORCE\: (.*)$'
[[ $* =~ "Open TimeMachineLog" ]] && /usr/bin/open -b org.gettes.TimeMachineLog
[[ $* =~ "Start Monitor" && -n "$MonPIDS" ]] && kill -TERM $MonPIDS
[[ $* =~ "Start Monitor" ]] && /usr/bin/open -b org.gettes.TimeMachineMonitor
[[ $* =~ "End Monitor" ]] && kill -TERM $MonPIDS
[[ $* =~ "TimeMachineMonitor on GitHub" ]] && /usr/bin/open "http://github.com/gettes/TimeMachineMonitor"
[[ $* =~ "Install LoginItems" ]] && InstallLoginItems
[[ $* =~ "Remove LoginItems" ]] && RemoveLoginItems
[[ $* =~ $e1 ]] && /usr/sbin/diskutil eject "${BASH_REMATCH[1]}"
[[ $* =~ $e2 ]] && /usr/sbin/diskutil unmount force "${BASH_REMATCH[1]}"

timeRemaining=$(/usr/bin/tmutil status | /usr/bin/grep TimeRemaining)
if [ $? -eq 0 ]; then
	tRE='^.*= ([0-9]+);'
	[[ "$timeRemaining" =~ $tRE ]] && timeRemaining=${BASH_REMATCH[1]}
	printf -v timeRemaining '      about %dh %dm %ss to go;  ' $(($timeRemaining / 3600)) $((($timeRemaining / 60) % 60)) $(($timeRemaining % 60))
else timeRemaining="                     "
fi

TMvols=( $Vols )
TMmounted=0
IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
mntvols=( $(/sbin/mount -vt afpfs,smbfs,hfs,apfs,exfat) )
#mntvols=( $(/bin/cat ./mount.out) ) # for debugging
#TMvols=( $(/bin/cat ./vol.out) ) # for debugging
IFS=$IFSBAK

monTime="" ; monStatus=""; monTimeStart=""; monStatus2=""; st_items=""
MonCount=$(/bin/ps axw | /usr/bin/grep TimeMachineMonitor.app/Contents/Resources/script | /usr/bin/grep -v /usr/bin/grep | /usr/bin/wc -l | /usr/bin/awk '{print $1}')
MonStatus="******   Monitor is NOT Running   ******" ; MonActive="DISABLED|" ; MonSUB="Start Monitor"
if [ $MonCount -eq 1 -a -f "$STATUSFILE" ]; then
	st_RE='^([0-9]+) (.+)$'
	now=$(/bin/date -j -f '%a %b %d %T %Z %Y' "$(/bin/date)" '+%s')
	IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
	st_file=( $(/bin/cat $STATUSFILE) )
	IFS=$IFSBAK
	[[ "${st_file[${#st_file[@]}-1]}" =~ $st_RE ]] && monTime=${BASH_REMATCH[1]} && monStatus=${BASH_REMATCH[2]}
	[[ "${st_file[0]}" =~ $st_RE ]] && monTimeStart=${BASH_REMATCH[1]} && monStatusStart=${BASH_REMATCH[2]}
	diff=$(( $now - $monTime ))
	printf -v monTime ': %dh %dm ago: %s' $(($diff / 3600)) $((($diff / 60) % 60)) "$monStatus"
	diff=$(( $now - $monTimeStart ))
	printf -v monTimeStart '%s %dh %dm ago: %s' "$timeRemaining" $(($diff / 3600)) $((($diff / 60) % 60)) "$monStatusStart"
	MonStatus="Monitor Running${monTime}" ; MonActive="DISABLED|" ; MonSUB="End Monitor"; MonStatus2="${monTimeStart}"
	for st_cnt in $(seq 0 ${#st_file[@]}) ; do
		st_time=""
		if [[ "${st_file[$st_cnt]}" =~ $st_RE ]]; then
			st_time=${BASH_REMATCH[1]} ; st_status=${BASH_REMATCH[2]}
		fi
		[[ -z "$st_time" ]] && continue
		diff=$(( $now - $st_time ))
		printf -v st_item '%02d:%02d:%02d %s' $(($diff / 3600)) $((($diff / 60) % 60)) $(($diff % 60)) "$st_status"
		[[ -z "$st_items" ]] && st_items=$st_item && continue
		st_items="$st_item|$st_items"
	done
	st_items="    Age      Status|$st_items"
fi

if [ $MonCount -eq 1 ]; then
/bin/cat <<HERE
${MonActive}MENUITEMICON|AppIcon.icns|  $MonStatus
${MonActive}$MonStatus2
SUBMENU|     Status History for last Backup|$st_items
SUBMENU|     Monitor Actions|Open TimeMachineLog|$MonSUB|Install LoginItems|Remove LoginItems
----
HERE
else
/bin/cat <<HERE
${MonActive}MENUITEMICON|AppIcon.icns|  $MonStatus
SUBMENU|     Monitor Actions|Open TimeMachineLog|$MonSUB|Install LoginItems|Remove LoginItems
----
HERE
fi

for vol in "${TMvols[@]}"; do
	ismntvol=0
	if [ ${#mntvols[@]} -gt 0 ]; then
		for cnt in $(seq 0 $((${#mntvols[@]} - 1))); do
			mntvol="${mntvols[$cnt]}"
			[[ $mntvol == "/" ]] && mntvol = "/Volumes/Macintosh HD"
			if [[ $mntvol =~ $NETRE ]]; then
				mntvol=${BASH_REMATCH[2]}
			fi
			[[ $mntvol =~ ^$vol ]] && ismntvol=1 && break
		done
	fi
	TM="    "; TMmark=" -> "
	[[ $vol =~ ^$TMvol\.$SNAP ]] && continue
	[[ $vol =~ "Time Machine Backups" ]] && TM=$TMmark && TMmounted=1
	[[ $vol =~ ^$TMvol && $ismntvol -eq 1 ]] && TM=$TMmark && TMmounted=1
	[[ $vol =~ ^$TMvol2 && $ismntvol -eq 1 ]] && TM=$TMmark && TMmounted=1
	[[ $vol =~ ^$TMvol2 && $ismntvol -eq 0 ]] && TM=$TMmark && continue
	[[ $vol = "/Volumes/Recovery" ]] && echo "DISABLED|$TMmark$vol" && continue
	[[ $TMmounted -eq 1 ]] && echo "DISABLED|$TM$vol" && continue
	[[ $TMmounted -eq 0 && $vol != "/Volumes/Macintosh HD" ]] && echo "SUBMENU|$TM$vol|EJECT: $vol|FORCE: $vol" && continue
	echo "DISABLED|$TM$vol"
done

#if [ $TMmounted -eq 1 ]; then
#/bin/cat <<HERE
#----
#DISABLED|
#DISABLED|**** Time Machine appears to be active
#DISABLED|
#DISABLED|     DO NOT close your laptop or eject Time Machine devices
#DISABLED|
#DISABLED|     Wait for Time Machine to finish!
#DISABLED|
#HERE
#else
#/bin/cat <<HERE
#----
#DISABLED|  Time Machine doesn't appear to be running
#DISABLED|  Should now be safe to eject Time Machine devices
#DISABLED|    and/or close your laptop
#HERE
#fi

/bin/cat <<HERE
----
MENUITEMICON|AppIcon.icns|  TimeMachineMonitor on GitHub
HERE

exit
