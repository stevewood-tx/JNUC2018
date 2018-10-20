#!/bin/sh

###############################################################################
#
# Name: baseProvisioning-TEMPLATE.sh
# Version: 1.0
# Date:  8 Sep 2018
# Modified: 
#
# Author:  Steve Wood (steve.wood@omnicomgroup.com)
# Purpose:  provisioning script used to put base layer of apps on a machine.
# 
###############################################################################

## Set global variables

LOGPATH='/private/var/omc/logs'
LOGFILE=$LOGPATH/all-base-provisioning-$(date +%Y%m%d-%H%M).log
VERSION=2.2
DNLOG='/var/tmp/depnotify.log'
defaults='/usr/bin/defaults'
surveyPlist='/private/var/omc/com.omnicom.survey.plist'
serial=$(system_profiler SPHardwareDataType | awk '/Serial\ Number\ \(system\)/ {print $NF}');

## setup number of DEP Notify stages for the progress bar
if [[ ! $6 ]]; then
	
	dnStages=15
	
else
	
	dnStages=$6
	
fi

## Setup logging
if [[ ! -d $LOGPATH ]]; then
	
	mkdir -p $LOGPATH
	chmod -R 777 $LOGPATH
	
fi
set -xv; exec 1> $LOGFILE 2>&1

## setup Caffeinate to stay awake
/bin/echo "Loads of Coffee Now!!"
/bin/date
caffeinate -d -i -m -u &
caffeinatepid=$!

## Setting up DEPNotify
## get logo and store in /var/omc
curl -sKO https://s3-us-west-2.amazonaws.com/omc-endpoint-drop/Pickup/PaigeLogo.png -o /var/omc/paige.png

## setup command file
echo "Command: Image: /var/omc/paige.png" >> ${DNLOG}
echo "Command: Determinate: $dnStages" >> ${DNLOG}
echo "Command: MainText: We are installing software on your machine. This process could take up to 40 minutes to complete so please make sure your computer is plugged in to power, and please do not restart until we are finished. Your computer will restart when we are done." >> ${DNLOG}
echo "Status: Starting installations" >> ${DNLOG}

echo "Creating DEPNotify LaunchAgent"
/bin/echo "<?xml version="1.0" encoding="UTF-8"?> 
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"> 
<plist version="1.0"> 
<dict>
    <key>Label</key>
    <string>com.corp.launchdepnotify</string>
    <key>ProgramArguments</key>
    <array>
        <string>/tmp/DEPNotify.app/Contents/MacOS/DEPNotify</string>
		<string>-fullScreen</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict> 
</plist>" > /Library/LaunchAgents/com.omnicomgroup.launchdepnotify.plist
##Set the permission on the file just made.
/usr/sbin/chown root:wheel /Library/LaunchAgents/com.omnicomgroup.launchdepnotify.plist
/bin/chmod 644 /Library/LaunchAgents/com.omnicomgroup.launchdepnotify.plist

## Now launch DEP Notify
/bin/launchctl load /Library/LaunchAgents/com.omnicomgroup.launchdepnotify.plist

######################################################################################
# 
# 		Tasks that do not require access to the JSS
# 
######################################################################################

####
# grab the OS version and Model, we may need it later
####

modelName=`system_profiler SPHardwareDataType | awk -F': ' '/Model Name/{print $NF}'`

######################################################################################
# Dummy package with image date and computer Model
# - this can be used with an ExtensionAttribute to tell us when the machine was last imaged
######################################################################################
/bin/echo "Creating provisioning receipt..."
/bin/date
TODAY=`date +"%Y-%m-%d"`
touch /Library/Application\ Support/JAMF/Receipts/$modelName_born_on_$TODAY.pkg
defaults write "$surveyPlist" ProvisionDate -string ${TODAY}

###############################################################################
#
#   S Y S T E M   P R E F E R E N C E S
#
# This section deals with system preference tweaks
#
###############################################################################
/bin/echo "Setting system preferences"
/bin/date

# Disable Time Machine's pop-up message whenever an external drive is plugged in
defaults write /Library/Preferences/com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

### time machine off
/bin/echo "Disable Time Machine"
/bin/date
/usr/bin/defaults write com.apple.TimeMachine 'AutoBackup' -bool false

# Disable “Application Downloaded from the internet” message
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.LaunchServices LSQuarantine -bool NO
defaults write com.apple.LaunchServices LSQuarantine -bool NO

# enable network time
systemsetup -setusingnetworktime on

# set the time server
systemsetup -setnetworktimeserver time.apple.com

#### below courtesy https://www.jamf.com/jamf-nation/discussions/6835/time-zone-using-current-location-scriptable#responseChild148977
/usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool YES
/usr/bin/defaults write /Library/Preferences/com.apple.locationmenu ShowSystemServices -bool YES

#Python code snippet to reload AutoTimeZoneDaemon
/usr/bin/python << EOF
from Foundation import NSBundle
TZPP = NSBundle.bundleWithPath_("/System/Library/PreferencePanes/DateAndTime.prefPane/Contents/Resources/TimeZone.prefPane")
TimeZonePref          = TZPP.classNamed_('TimeZonePref')
ATZAdminPrefererences = TZPP.classNamed_('ATZAdminPrefererences')

atzap  = ATZAdminPrefererences.defaultPreferences()
pref   = TimeZonePref.alloc().init()
atzap.addObserver_forKeyPath_options_context_(pref, "enabled", 0, 0)
result = pref._startAutoTimeZoneDaemon_(0x1)
EOF

sleep 1
#Get the time from time server
/usr/sbin/systemsetup -getnetworktimeserver

#Detect the newly set timezone
/usr/sbin/systemsetup -gettimezone

# disable the save window state at logout
/usr/bin/defaults write com.apple.loginwindow 'TALLogoutSavesState' -bool false
				
###########
#  AFP
###########

# enforce clear text passwords in AFP
/bin/echo "Setting AFP clear text to disabled"
/bin/date
/usr/bin/defaults write com.apple.AppleShareClient "afp_cleartext_allow" 0

# Turn off DS_Store file creation on network volumes
/bin/echo "Turn off DS_Store"
/bin/date
defaults write /System/Library/User\ Template/English.lproj/Library/Preferences/com.apple.desktopservices \
	DSDontWriteNetworkStores true

	
###  Expanded print dialog by default
# <http://hints.macworld.com/article.php?story=20071109163914940>
#
/bin/echo "Expanded print dialog by default"
/bin/date
# expand the print window
defaults write /Library/Preferences/.GlobalPreferences PMPrintingExpandedStateForPrint2 -bool TRUE

##########################################
# /etc/authorization changes
##########################################

security authorizationdb write system.preferences allow
security authorizationdb write system.preferences.datetime allow
security authorizationdb write system.preferences.printing allow
security authorizationdb write system.preferences.energysaver allow
security authorizationdb write system.preferences.network allow 
security authorizationdb write system.services.systemconfiguration.network allow

## add users to lpadmin
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group lpadmin
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group _lpadmin
/usr/sbin/dseditgroup -o edit -n /Local/Default -a 'Domain Users' -t group lpadmin

# check for jamf binary
/bin/echo "Checking for JAMF binary"
/bin/date

 if [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ ! -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/sbin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ ! -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/local/bin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/local/bin/jamf"
 fi

${jamf_binary} flushPolicyHistory
${jamf_binary} recon

sleep 5

### Installing base image software
echo "Status: Begining software installations" >> $DNLOG

## Common Resources
/bin/echo "Installing Common Resources"
/bin/date
${jamf_binary} policy -id 24 --forceNoRecon # AnyConnect, dockutil, cocoaDialog, VLC
${jamf_binary} policy -id 120 --forceNoRecon # SwapNetwork

echo "Status: Common resources installed" >> $DNLOG

## Internet Plug-Ins
/bin/echo "Installing Internet Plug-ins"
/bin/date
${jamf_binary} policy -id 36 --forceNoRecon #Java, Silverlight

echo "Status: Installing printer drivers." >> $DNLOG

## Printer Drivers
/bin/echo "Installing Printer Drivers"
/bin/date
${jamf_binary} policy -id 862 --forceNoRecon # Xerox Driver
${jamf_binary} policy -id 863 --forceNoRecon # HP Driver
${jamf_binary} policy -id 623 --forceNoRecon # Canon PS Driver

echo "Status: Printer drivers installed" >> $DNLOG
echo "Status: Installing web browsers." >> $DNLOG

## Web Browsers
/bin/echo "Installing Web Browsers"
/bin/date
${jamf_binary} policy -id 55 --forceNoRecon # Firefox
${jamf_binary} policy -id 10 --forceNoRecon # Chrome

echo "Status: Web browsers installed" >> $DNLOG
echo "Status: Installing Office 2016." >> $DNLOG

## Office 2016
/bin/echo "Installing Office 2016"
/bin/date
${jamf_binary} policy -id 104 --forceNoRecon # Full Office Suite

echo "Status: Office 2016 installed" >> $DNLOG
echo "Status: Installing Skype for Business." >> $DNLOG

## Skype for Biz
/bin/echo "Installing Skype for Business"
/bin/date
${jamf_binary} policy -id 49 --forceNoRecon # Skype for Biz

echo "Status: Skype for Business installed" >> $DNLOG

echo "Status: Updating computer inventory." >> $DNLOG
# recon
${jamf_binary} recon

## upload log to JPS
#Decypt string 
function DecryptString() {
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

apiUser=$(DecryptString $4 '2e8ae0cfc360c410' '6dc974aeee54c08a91d1ba4b')
apiPass=$(DecryptString $5 'aee810da39e48b93' 'e78b44b6e96bf2892bc06de4')
jpsURL="https://admin.jamf.omnicomgroup.com"

## get ID of computer
JSS_ID=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jpsURL}/JSSResource/computers/serialnumber/${serial}/subset/general" | xpath /computer/general/id[1] | awk -F'>|<' '{print $3}')
curl -sku $apiUser:$apiPass $jpsURL/JSSResource/fileuploads/computers/id/$JSS_ID -F name=@${LOGFILE} -X POST

/bin/echo "Evacuating coffee"
/bin/date
kill "$caffeinatepid"

## clean up log file
srm $LOGFILE