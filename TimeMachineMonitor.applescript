tell application "Terminal"
	activate
	do script "$HOME/bin/TimeMachineMonitor.sh >> /tmp/TimeMachineMonitor.txt"
end tell

