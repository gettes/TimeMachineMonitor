#!/bin/bash

# Michael R Gettes, gettes@gmail.com, August, 2019

APP="VolumeStatus"
SNAP="localsnapshots"
TMvol="/Volumes/com.apple.TimeMachine"
Vols="/Volumes/"
NETRE='^(.+) on (.+) \((.+),.*'
DATE() { /bin/date "+%Y-%m-%d %H:%M:%S" ; }
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
	set p to POSIX path of ((application file id "org.gettes.TimeMachineMonitor") as alias)
	tell application "System Events" to make login item at end with properties {name:"TimeMachineMonitor", path:p, hidden:true}

	try
		tell application "System Events" to delete login item "TimeMachineStatus"
	end try
	set p to POSIX path of ((application file id "org.gettes.TimeMachineStatus") as alias)
	tell application "System Events" to make login item at end with properties {name:"TimeMachineStatus", path:p, hidden:true}
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

[[ $* =~ "Open TimeMachineLog" ]] && /usr/bin/open -b org.gettes.TimeMachineLog
[[ $* =~ "Start Monitor" && -n "$MonPIDS" ]] && kill $MonPIDS
[[ $* =~ "Start Monitor" ]] && /usr/bin/open -b org.gettes.TimeMachineMonitor
[[ $* =~ "End Monitor" ]] && kill $MonPIDS
[[ $* =~ "TimeMachineMonitor on GitHub" ]] && /usr/bin/open "http://github.com/gettes/TimeMachineMonitor"
[[ $* =~ "Install LoginItems" ]] && InstallLoginItems
[[ $* =~ "Remove LoginItems" ]] && RemoveLoginItems

TMvols=( $Vols* )
TMmounted=0
IFSBAK=$IFS; IFS=$'\n' # change IFS so the following will work
mntvols=( $(/sbin/mount -vt afpfs,smbfs,hfs,apfs,exfat) )
#mntvols=( $(/bin/cat ./mount.out) ) # for debugging
#TMvols=( $(/bin/cat ./vol.out) ) # for debugging
IFS=$IFSBAK

MonCount=$(/bin/ps axw | /usr/bin/grep TimeMachineMonitor.app/Contents/Resources/script | /usr/bin/grep -v /usr/bin/grep | /usr/bin/wc -l | /usr/bin/awk '{print $1}')
MonStatus="******   Monitor is NOT Running   ******" ; MonActive="DISABLED|" ; MonSUB="Start Monitor"
[[ $MonCount -eq 2 ]] && MonStatus="Monitor Running" && MonActive="DISABLED|" && MonSUB="End Monitor"

/bin/cat <<HERE
${MonActive}MENUITEMICON|AppIcon.icns|  $MonStatus
SUBMENU|     Monitor Actions|Open TimeMachineLog|$MonSUB|Install LoginItems|Remove LoginItems
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
MENUITEMICON|AppIcon.icns|  TimeMachineMonitor on GitHub
HERE

exit
