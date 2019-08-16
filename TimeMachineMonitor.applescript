tell application "Terminal"
	activate
	# the following executes the monitor in the background and follows with monitoring the log output
	do script "/bin/sh -c '$HOME/bin/TimeMachineMonitor.sh 2>&1 >> /tmp/TimeMachineMonitor.log & /usr/bin/tail -F /tmp/TimeMachineMonitor.log'"
end tell

