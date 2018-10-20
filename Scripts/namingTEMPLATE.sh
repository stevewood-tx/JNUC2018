#!/bin/bash

###############################################################################
# Name: namingTEMPLATE.sh
# Date: 8 Sep 2018
# Update: 
# Author: Steve Wood (steve.wood@omnicomgroup.com)
# Purpose: Used to re-name computers and grab user info on machines that only
#			need to have the base provisioning completed.
#
##############################################################################
# setup logging
logFile="/path/to/your/nameComputer.log"

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

ScriptLog "Starting"

# cocoaDialog path
CD="/usr/local/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
JH="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
defaults='/usr/bin/defaults'
surveyPlist='/path/to/survey/com.company.survey.plist'

# Wait for Finder
while ! pgrep -xq Finder; do
    echo "waiting for Finder"
    sleep 10
done

if [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ ! -e "/usr/local/bin/jamf" ]]; then
	jamf_binary="/usr/sbin/jamf"
elif [[ "$jamf_binary" == "" ]] && [[ ! -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
	jamf_binary="/usr/local/bin/jamf"
elif [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
	jamf_binary="/usr/local/bin/jamf"
fi

ScriptLog "Installing cocoaDialog"
if [[ ! -e $CD ]]; then

	${jamf_binary} policy -trigger cocoaDialog
	
fi

## grab the machine serial number
serial=$(system_profiler SPHardwareDataType | awk '/Serial\ Number\ \(system\)/ {print $NF}');
ScriptLog "Machine serial number: $serial"

## Grab machine IP Address
/bin/echo "Grabbing IP Address"
/bin/date
ActivePort=$( /usr/sbin/netstat -rn 2>&1 | /usr/bin/grep -m 1 'default' | awk '{print $NF}' )
IPAddress=$( ipconfig getifaddr "$ActivePort" )
ScriptLog "Machine IP Address: $IPAddress"

## Get Country
country=`$CD standard-dropdown --height 125 --title "Country" --text "Please choose the Country:" --float --no-cancel --items "Canada" "United States" --string-output --icon gear`
country=`echo $country | cut -d' ' -f2-`

case ${country} in

'Canada')
	countryCode='CA'
	;;

'United States') ## <<-- use single quotes if case has a space in it
	countryCode='US'
	;;

esac

## Get the Agency ##
agency=`$CD standard-dropdown --height 125 --title "Agency" --text "Please choose the Agency:" --float --no-cancel --items "Company1" "Company2" \
	"Company3" --string-output --icon gear`
agency=`echo $agency | cut -d' ' -f2-`

## get the code for the name
case ${agency} in
	
Company1) ## <<-- use single quotes if case has a space in it
	agencyCode='CO1'
	;;
	
Company2)
	agencyCode='CO2'
	;;
Company3)
	agencyCode='CO3'
	;;
esac
	
## start building computer name. If you are not setting the computer name programatically, you can remove 
## this section.

unique_id=${serial:3:7} ## grab 7 digits starting with 4th digit of serial number

compName="${countryCode}5${agencyCode}M0${unique_id}"  ## build the computer name
showCompName=`$CD ok-msgbox --no-cancel --title "Computer Name" --text "Computer name: ${compName}" --icon-file /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns`
ScriptLog "Machine name: $compName"
###

## User Email ##
userEmail=`$CD standard-inputbox --title "User Email" --informative-text "Please enter the email of the end user(leave blank if machine is unassigned):" --float --icon gear`
userEmail=`echo $userEmail | cut -d' ' -f2-`

## User Department ##
# get their role: Creative, Client Leadership, etc
userDep=`$CD standard-dropdown --height 125 --title "Department" --text "Please choose the appropriate role:" --float --no-cancel --items "Account" "Administrative" \
    "Client Leadership" "Creative" "Design" "Developer" "Digital" "Executives" "Finance" "Freelance" \
        "HR" "IT" "Media" "Planning" "Prouction" "Project Management" "Retouching" "Studio" "Video" --string-output --icon gear`
userDep=`echo $userDep | cut -d' ' -f2-`

## City ##
city=`$CD standard-dropdown --height 125 --title "City" --text "Please choose the city this computer will be in:" --float --no-cancel --icon gear \
	--items "Atlanta" "Chicago" "New York" "San Francisco" "Seattle" "Toronto" --string-output`
city=`echo $city | cut -d' ' -f2-`

## Asset Tag ##
assetTag=`$CD standard-inputbox --title "Asset Tag" --informative-text "Please enter the asset tag of the machine:" --float --icon gear`
assetTag=`echo $assetTag | cut -d' ' -f2-`

# set the computer name
/bin/echo "Set Computer Name"
/bin/date
${jamf_binary} setComputerName -name ${compName}

## Write values to plist
/bin/echo "Writing to plist"
/bin/date
${defaults} write "${surveyPlist}" City "${city}"
${defaults} write "${surveyPlist}" Country "${country}"
${defaults} write "${surveyPlist}" Department "${userDep}"
${defaults} write "${surveyPlist}" Company "${agency}"
${defaults} write "${surveyPlist}" ProvisionedIP ${IPAddress}
${defaults} write "${surveyPlist}" Email "${userEmail}"
${defaults} write "${surveyPlist}" ComputerName "${compName}"
${defaults} write "${surveyPlist}" AssetTag "${assetTag}"

## echo values into the log file
ScriptLog "City: ${city}"
ScriptLog "Country: ${country}"
ScriptLog "Company: ${agency}"
ScriptLog "Department: ${userDep}"
ScriptLog "Email: ${userEmail}"
ScriptLog "Computer Name: ${compName}"
ScriptLog "Asset Tag: ${assetTag}"
ScriptLog "ProvisionedIP: ${IPAddress}"


## give the user/tech something to see while we do our recon. This keeps them from thinking we're stalled out

"$JH" -windowType hud -title Provisioning \
	-heading "Starting Provisioning" -description "We are downloading some pieces for provisioning. We will continue in a minute." \
		-alignDescription left -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Clock.icns" -lockHUD &

${jamf_binary} recon -endUsername "${userEmail}" -email "${userEmail}" -assetTag "${assetTag}" -department "${userDep}" -room "${agency}"

## upload log file
#Decypt string 
function DecryptString() {
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

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

exit 0