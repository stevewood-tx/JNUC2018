#!/bin/bash

# Name: omc-os-update-deferral.sh
# Date: 31 Jul 2017
# Author: Mike Levenick (mike.levenick@jamf.com) adjustments by Steve Wood (steve.wood@omnicomgroup.com)
# Purpose: to provide a way to defer software update up to a set number of times.

# setup logging
logFile="/var/log/os-update-deferral.log"

# Check for / create logFile
if [ ! -f "${logFile}" ]; then
    # logFile not found; Create logFile
    /usr/bin/touch "${logFile}"
fi

function ScriptLog() { # Re-direct logging to the log file ...

    exec 3>&1 4>&2        # Save standard output and standard error
    exec 1>>"${logFile}"    # Redirect standard output to logFile
    exec 2>>"${logFile}"    # Redirect standard error to logFile

    NOW=`date +%Y-%m-%d\ %H:%M:%S`    
    /bin/echo "${NOW}" " ${1}" >> ${logFile}

}

ScriptLog

#path to jamfhelper
jhpath="/Library/Application Support/JAMF/bin/jamfhelper.app/Contents/MacOS/jamfhelper"

#path to counter file
counterpath="/Library/Application Support/JAMF/com.yourcompany.osupdatedeferral.plist"

#check if counter file exists. If it does, increment the count and store it
if [ -f "$counterpath" ]; then
	echo "Counter file found."
	count=`defaults read "$counterpath" DeferralCount`
	echo "Old count is $count"
	((count++))
	echo "New count is $count"
	defaults write "$counterpath" DeferralCount -int $count

#if the counter file is not found, create one with count 0
else 
	echo "Counter file does not exist. Creating one now."
	defaults write "$counterpath" DeferralCount -int 0
	count=0
	echo "Count is $count"
fi

#deletes the count file. For testing and debugging
#rm "$counterpath"

if [ "$count" -le 2 ]; then
	if [ "$count" -eq 2 ] ; then
		prompt=$("$jhpath" -startlaunchd -windowType hud -lockHUD -title "macOS Upgrade Required" -icon "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns" -heading "Final Warning" -description "There is a required OS upgrade available for your computer. You have already deferred the update $count times. If you do not choose to upgrade now, the upgrade will happen automatically in 24 hours time." -button1 "Update" -button2 "Defer" -defaultButton 1)
	else
		prompt=$("$jhpath" -startlaunchd -windowType hud -lockHUD -title "macOS Upgrade Required" -icon "/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns" -heading "macOS Upgrade Available" -description "There is a required OS upgrade available for your computer. Would you like to upgrade now, or defer the upgrade one day? You may defer the upgrade up to 3 times before the option to delay will be taken away. You have deferred $count times." -button1 "Update" -button2 "Defer" -defaultButton 1)
	fi
	if [ $prompt = 0 ]; then

		#upgrade
		echo "upgrade"
		sudo jamf policy -event "updateOS" #uncomment to trigger upgrade

		# reset counter
		rm "$counterpath"
	else

		#dontupgrade
		echo "don't upgrade"

	fi
else
	final=$("$jhpath" -startlaunchd -windowType hud -lockHUD -title "macOS Upgrade Required" -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" -heading "macOS Upgrade Available" -description "There is a required OS upgrade available for your computer. You have already deferred this upgrade $count times. The upgrade will now begin." -button1 "Ok" -defaultButton 1)

	echo "upgrade"
	sudo jamf policy -event "updateOS" #uncomment to trigger upgrade

	# reset counter
	rm "$counterpath"
fi