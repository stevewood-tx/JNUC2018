#!/bin/sh

###############################################################################
#
# Name: businessUnit-provisioning.sh
# Version: 1.0
# Date:  11 Apr 2018
# Modified: 
# Author:  Steve Wood (steve.wood@omnicomgroup.com)
# Purpose:  provisioning script used for base load
# 
###############################################################################

## Set global variables

LOGPATH='/path/to/your/logs'
LOGFILE=$LOGPATH/businessUnit-provisioning-$(date +%Y%m%d-%H%M).log
VERSION=1.7
CD="/usr/local/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
defaults='/usr/bin/defaults'
surveyPlist='/path/to/your/com.company.survey.plist'
DNLOG='/var/tmp/depnotify.log'

# setup logging
if [[ ! -d ${LOGPATH} ]]; then
	## Setup logging
	mkdir -p $LOGPATH
fi

set -xv; exec 1> $LOGFILE 2>&1

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

${jamf_binary} policy -trigger acrobatDC --forceNoRecon # Acrobat DC

## check if creative

case ${build} in
	
Creative)

	${jamf_binary} policy -trigger illus2018 --forceNoRecon # Illustrator
	${jamf_binary} policy -trigger indesing2018 --forceNoRecon # InDesign
	${jamf_binary} policy -trigger photoshop2018 --forceNoRecon # Photoshop
	${jamf_binary} policy -trigger bridge2018 --forceNoRecon # Bridge
;;	

esac

${jamf_binary} policy -trigger ccdaElevated --forceNoRecon # CC Elevated app

### Install the "core" software
echo "Status: Installing TMA Printer Drivers" >> ${DNLOG}
## Printer Drivers
/bin/echo "Installing Printer Drivers"
/bin/date
${jamf_binary} policy -trigger cpassGX500 --forceNoRecon # ColorPass GX500
${jamf_binary} policy -trigger cpassGX400 --forceNoRecon # ColorPass GX400
${jamf_binary} policy -trigger imagepassB2 --forceNoRecon # CN_imagePASS_B2_v1_0R_FD51_v2

echo "Status: Installing AnyConnect Profile" >> ${DNLOG}
## Sophos
/bin/echo "Installing AnyConnect Profile"
/bin/date
${jamf_binary} policy -trigger anyConnectProfile --forceNoRecon # AnyConnect Profile

echo "Status: Installing Universal Type Client" >> ${DNLOG}
## UTC
/bin/echo "Installing UTC"
/bin/date
${jamf_binary} policy -trigger utc6 --forceNoRecon # UTC
${jamf_binary} policy -trigger utcPrefs --forceNoRecon # UTC Prefs

echo "Status: Installing  Zoom" >> ${DNLOG}
## Sophos
/bin/echo "Installing Zoom"
/bin/date

${jamf_binary} policy -trigger zoom --forceNoRecon # Zoom
${jamf_binary} policy -trigger zoomOutlook --forceNoRecon # Zoom Outlook Plug-In

echo "Status: Installing Wacom drivers" >> ${DNLOG}
## Wacom
/bin/echo "Installing Wacom"
/bin/date
${jamf_binary} policy -trigger wacom --forceNoRecon # Wacom

echo "Status: Installing Box Sync" >> ${DNLOG}
## Wacom
/bin/echo "Installing Box Sync"
/bin/date
${jamf_binary} policy -trigger boxSync --forceNoRecon # Box SYnc

## Finder Settings
/bin/echo "Installing Finder"
/bin/date
${jamf_binary} policy -trigger finderPrefs --forceNoRecon # Finder

echo "Status: Installing Computrace" >> ${DNLOG}
## Computrace
/bin/echo "Installing Computrace"
/bin/date
${jamf_binary} policy -trigger computrace --forceNoRecon # computrace

echo "Status: Installing Printers" >> ${DNLOG}

/bin/echo "Installing Printers based on location"
/bin/date

case ${city} in
	
Chicago)
	
	${jamf_binary} policy -trigger chicagoSecure ## Chicago printers
	${jamf_binary} policy -trigger chicagoPrinters ## Chicago printers
	
	;;
	
Dallas)
	
	${jamf_binary} policy -trigger dallasPrinters ## Dallas printers
	
	;;
	
Darien)
	
	${jamf_binary} policy -trigger darienPrinters ## Darien printers
	
	;;
	
Irvine)
	
	${jamf_binary} policy -trigger irvinePrinters ## Irvine printers
	
	;;
	
"New York")
	
	${jamf_binary} policy -trigger nycPrinters ## New York printers
	
	;;
	
"Los Angeles")
	
	${jamf_binary} policy -trigger laPrinters ## Los Angeles printers
	
	;;
esac
	
## disabling FileVault pass thru authentication
defaults write /Library/Preferences/com.apple.loginwindow DisableFDEAutoLogin -bool YES

touch /Library/Application\ Support/JAMF/Receipts/businessUnit-provisiondone.pkg

echo "Status: Running Software Update" >> ${DNLOG}
/bin/echo "Apple Software Updates"
/bin/date
/usr/sbin/softwareupdate --clear-catalog
/usr/sbin/softwareupdate -ia

echo "Status: Updating computer inventory" >> ${DNLOG}
${jamf_binary} recon

## upload log to JPS
#Decypt string 
function DecryptString() {
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

apiUser=$(DecryptString $4 '<yoursalt>' '<yourkey>')
apiPass=$(DecryptString $5 '<yoursalt>' '<yourkey>')
jpsURL="https://your.jamfproserver.com"
serial=$(system_profiler SPHardwareDataType | awk '/Serial\ Number\ \(system\)/ {print $NF}');

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