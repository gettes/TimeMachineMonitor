## TimeMachineMonitor / TimeMachineLog / TimeMachineStatus
Monitor Apple TimeMachine Backups
for Sierra (MacOS 12) and later systems since Sept 2016

Apple's TimeMachine really does make backups easy.
There is a flaw for those with laptops.  The laptop is portable, connecting and disconnecting
physical devices is annoying.  Network drives for TimeMachine are great.  However, they don't always
properly disconnect.  And here is why these 3 apps exist.  I have found when TimeMachine volumes
are not properly dismounted and disconnected strange things happen.  The laptop may not properly
restart.  There may be strange application behavior over time.  Ensuring TimeMachine volumes
are properly dismounted has eliminated all these strange behaviors.  Ultimately, Apple should
fix TimeMachine so no volumes are mounted when TimeMachine isn't running - especially for Network
volumes.  Until then, these apps should assist with proper management of TimeMachine volumes.

## Thank you Platypus
Before reading any further proper credit needs to be given.
These apps were created using Platypus (https://github.com/sveinbjornt/Platypus), it allows one to
build wrapper applications to run shell scripts for Mac OS X.
The apps do not require any privileges nor do they do anything nefarious.  The code is included.

# To use
The easiest thing to do is to download the zip files, doubleclick/open them and move them where
you like to have your apps.

## TimeMachineLog

A simple app to display the logs related to TimeMachine and the TimeMachineMonitor.  As time goes
on you will probably never use this app.  In the beginning, especially for the curious, the app
helps you see why these apps were created.  The app runs the command:
```console
/usr/bin/log stream --style syslog  --info --predicate '(processImagePath contains "backupd" and subsystem beginswith "com.apple.TimeMachine") || (eventMessage contains "TimeMachineMonitor:")'
```

## TimeMachineMonitor

You will want to make this a Login Item in System Preferences > Users & Groups.
It essentially runs as a background process watching the TimeMachine logs for events
requiring an unmount of the TimeMachine volumes when they aren't properly unmounted.

Technical details: the app runs a very small but elegant bash script handling subshells,
signals, and events to properly watch over TimeMachine and only unmount TimeMachine volumes
when it is safe to do so.  Just because TimeMachine indicates it is finished with a backup
unfortunately doesn't mean it has actually completed.  TimeMachineMonitor will unmount
only when it is safe and requires no privileges to do what it does.  It watches the logs
and it uses Disk Utility to unmount volumes.

## TimeMachineStatus

You will also want to make this a Login Item in System Preferences > Users & Groups.
It provides a menu bar item you click on and it tells you if TimeMachine is active.
Checking the status before you close your laptop will help you safely close after TimeMachine
has fully finished doing what it needs to do.

-------

No warranties are implied with using this software.  Use at your own risk.
You accept all responsibilities for running the software.
