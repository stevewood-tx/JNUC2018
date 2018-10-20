#!/bin/sh

###############################################################################
#
# Name: das-tma-provisioning.sh
# Version: 1.7
# Date:  11 Apr 2018
# Modified: 2 May 2018
#	        21 May 2018 - added Fiery drivers
#			5 July 2018 - adding creative build
#			10 Jul 2018 - adding printer logic, Apple SWU
#           18 Jul 2018 - added WebEx and Zoom
# Author:  Steve Wood (steve.wood@omnicomgroup.com)
# Purpose:  provisioning script used for base load
# 
###############################################################################

## Set global variables

LOGPATH='/private/var/omc/logs'
LOGFILE=$LOGPATH/das-tma-provisioning-$(date +%Y%m%d-%H%M).log
VERSION=1.7
CD="/usr/local/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
defaults='/usr/bin/defaults'
surveyPlist='/var/omc/com.omnicom.survey.plist'
DNLOG='/var/tmp/depnotify.log'

# setup logging
if [[ ! -d ${LOGPATH} ]]; then
	## Setup logging
	mkdir /private/var/omc
	mkdir $LOGPATH
fi

set -xv; exec 1> $LOGFILE 2>&1

#Decypt string 
function DecryptString() {
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

#let's stay awake
/bin/echo "Loads of Coffee Now!!"
/bin/date
caffeinate -d -i -m -u &
caffeinatepid=$!

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

## downloading software udpates in the background
/bin/echo "Downloading Apple OS Updates"
/bin/date
/usr/sbin/softwareupdate --clear-catalog
/usr/sbin/softwareupdate -da & # using & to have this task run in the background while continuing script

## Get build type from OMC survey file
build=$( $defaults read "$surveyPlist" Department )
city=$( $defaults read "$surveyPlist" City )

echo "Status: Installing Adobe Products" >> ${DNLOG}
### INSTALLING ADOBE PRODUCTS
/bin/echo "Installing Adobe Apps"
/bin/date

${jamf_binary} policy -id 1214 --forceNoRecon # Acrobat DC

## check if creative

case ${build} in
	
Creative)

	${jamf_binary} policy -id 630 --forceNoRecon # Illustrator
	${jamf_binary} policy -id 631 --forceNoRecon # InDesign
	${jamf_binary} policy -id 635 --forceNoRecon # Photoshop
	${jamf_binary} policy -id 637 --forceNoRecon # Bridge
;;	

esac

${jamf_binary} policy -id 532 --forceNoRecon # CC Elevated app

### Install the "core" software
echo "Status: Installing TMA Printer Drivers" >> ${DNLOG}
## Printer Drivers
/bin/echo "Installing Printer Drivers"
/bin/date
${jamf_binary} policy -id 439 --forceNoRecon # ColorPass GX500
${jamf_binary} policy -id 1416 --forceNoRecon # ColorPass GX400
${jamf_binary} policy -id 1417 --forceNoRecon # CN_imagePASS_B2_v1_0R_FD51_v2
${jamf_binary} policy -id 1418 --forceNoRecon # CN_imagePASS_B2_v1_0R_FD51_v2

echo "Status: Installing AnyConnect Profile" >> ${DNLOG}
## Sophos
/bin/echo "Installing AnyConnect Profile"
/bin/date
${jamf_binary} policy -id 1446 --forceNoRecon # AnyConnect Profile

echo "Status: Installing Universal Type Client" >> ${DNLOG}
## UTC
/bin/echo "Installing UTC"
/bin/date
${jamf_binary} policy -id 91 --forceNoRecon # UTC
${jamf_binary} policy -id 1552 --forceNoRecon # UTC Prefs

echo "Status: Installing  Zoom" >> ${DNLOG}
## Sophos
/bin/echo "Installing Zoom"
/bin/date

${jamf_binary} policy -id 1158 --forceNoRecon # Zoom
${jamf_binary} policy -id 1344 --forceNoRecon # Zoom Outlook Plug-In

echo "Status: Installing Wacom drivers" >> ${DNLOG}
## Wacom
/bin/echo "Installing Wacom"
/bin/date
${jamf_binary} policy -id 858 --forceNoRecon # Wacom

echo "Status: Installing Box Sync" >> ${DNLOG}
## Wacom
/bin/echo "Installing Box Sync"
/bin/date
${jamf_binary} policy -id 1353 --forceNoRecon # Box SYnc

## Finder Settings
/bin/echo "Installing Finder"
/bin/date
${jamf_binary} policy -id 1375 --forceNoRecon # Finder
${jamf_binary} policy -id 1379 --forceNoRecon # Mid Admin
${jamf_binary} policy -id 1380 --forceNoRecon # Zidget

echo "Status: Installing Computrace" >> ${DNLOG}
## Computrace
/bin/echo "Installing Computrace"
/bin/date
${jamf_binary} policy -id 1374 --forceNoRecon # computrace

echo "Status: Installing Printers" >> ${DNLOG}

/bin/echo "Installing Printers based on location"
/bin/date

case ${city} in
	
Chicago)
	
	${jamf_binary} policy -id 1454 ## Chicago printers
	${jamf_binary} policy -id 1495 ## Chicago printers
	
	;;
	
Dallas)
	
	${jamf_binary} policy -id 1451 ## Dallas printers
	
	;;
	
Darien)
	
	${jamf_binary} policy -id 1455 ## Darien printers
	
	;;
	
Irvine)
	
	${jamf_binary} policy -id 1456 ## Irvine printers
	
	;;
	
"New York")
	
	${jamf_binary} policy -id 1453 ## New York printers
	
	;;
	
"Los Angeles")
	
	${jamf_binary} policy -id 1597 ## Los Angeles printers
	
	;;
esac
	
# disable password expiration note at loginwindow
# per https://github.com/macmule/ADPassMon/wiki/Other-Settings#login-window-password-expiration
defaults write /Library/Preferences/com.apple.loginwindow PasswordExpirationDays 0

dscl . create /Users/omcadmin IsHidden 1

# Configure ARD with allowed users and their ARD rights
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs \
	 -DeleteFiles -ControlObserve -TextMessages -OpenQuitApps -GenerateReports -RestartShutdown -SendFiles -ChangeSettings -restart -agent -console
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

## disabling FileVault pass thru authentication
defaults write /Library/Preferences/com.apple.loginwindow DisableFDEAutoLogin -bool YES

touch /Library/Application\ Support/JAMF/Receipts/us-das-tma-provisiondone.pkg

echo "Status: Running Software Update" >> ${DNLOG}
/bin/echo "Apple Software Updates"
/bin/date
/usr/sbin/softwareupdate --clear-catalog
/usr/sbin/softwareupdate -ia

echo "Status: Updating computer inventory" >> ${DNLOG}
${jamf_binary} recon

## upload log to JPS
apiUser=$(DecryptString $4 'eb95be2b6190a00b' '9cf73208b6d5cc82ede3ef2b')
apiPass=$(DecryptString $5 'b2ff32193fb97e66' '08c289c01cbdcd08eb6ef508')
jpsURL="https://admin.jamf.omnicomgroup.com"

## get ID of computer
JSS_ID=$(curl -H "Accept: text/xml" -sfku "${apiUser}:${apiPass}" "${jpsURL}/JSSResource/computers/serialnumber/${serial}/subset/general" | xpath /computer/general/id[1] | awk -F'>|<' '{print $3}')
curl -sku $apiUser:$apiPass $jpsURL/JSSResource/fileuploads/computers/id/$JSS_ID -F name=@${LOGFILE} -X POST

/bin/echo "Evacuating coffee"
/bin/date
kill "$caffeinatepid"
rm -rf "/Applications/Caffeine.app"

## Kill off DEP Notify screen
echo "Command: Quit" >> $DNLOG
/bin/launchctl unload /Library/LaunchAgents/com.corp.launchdepnotify.plist
rm /Library/LaunchAgents/com.corp.launchdepnotify.plist

exit 0