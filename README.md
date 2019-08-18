# TimeMachineMonitor
Monitor Apple TImeMachine Backups and force unmount if needed - final

Watch Apple Time Machine backups (especially for network volumes)
should the volumes get stuck as Network volumes tend to do - force unmount when safe
network volumes have been getting stuck for years - at least in my experience.
Since I have been using this app on my laptop - volume corruptions have stopped and "weird things happening" have stopped.

Wait about 20 seconds after a backup completes (see log viewer app) or is cancelled to make sure the TM volume is gone.
The script works on High Sierra and beyond as "log stream" is needed now - logs used to be files.
This does handle multiple network volumes and odd timing conditions

Add TimeMachineMonitor.app as login item - No privs needed.
The app was created using Platypus (https://github.com/sveinbjornt/Platypus) a wrapper for shell scripts.
You will need to give permission for this unsigned app to run on your Mac.
While I do nothing malicious - you accept all responsibilties for running this application.

The logviewer app simply displays the output using the log command below.

to see TimeMachine and this monitor logging
log stream --style syslog  --info --predicate '(processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine") || (eventMessage contains "TimeMachineMonitor:")'
