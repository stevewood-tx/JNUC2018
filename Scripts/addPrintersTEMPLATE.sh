#!/bin/bash

# Name: addPrintersTEMPLATE.sh
# Date: 8 Sep 2018
# Author: Steve Wood (steve.wood@omnicomgroup.com)
# Update: 
# Purpose: add printers using a Case statement to choose

# setup logging
logFile="/var/log/add-printers.log"

# Check for / create logFile
if [ ! -f "${logFile}" ]; then
    # logFile not found; Create logFile
    /usr/bin/touch "${logFile}"
fi

function ScriptLog() { # Re-direct logging to the log file ...

    exec 3>&1 4>&2        # Save standard output and standard error
    exec 1>>"${logFile}"    # Redirect standard output to logFile
    exec 2>>"${logFile}"    # Redirect standard error to logFile

    NOW=`date '+%Y-%m-%d %H:%M:%S'`
    /bin/echo "${NOW}" " ${1}" >> ${logFile}

}
ScriptLog

## Setup variables
lpa='/usr/sbin/lpadmin'

## add printers
ScriptLog $4 ${NOW}

## check for the proper printer drivers. Add if/them statements for each driver
if [[ ! -f "/Library/Printers/PPDs/Contents/Resources/HP Color MFP E87640-50-60.gz" ]]; then
	
	/usr/local/bin/jamf policy -id 1680
	
fi

ScriptLog "Adding $4"

case "$4" in

	Printer1) ## each printer individually
	
	${lpa} -p  PRINTER1 -E -o printer-is-shared=false -v ipp://10.1.1.1 -D "PRINTER1" -P "/Library/Printers/PPDs/Contents/Resources/HP Color MFP E87640-50-60.gz"
	${lpa} -p  PRINTER1 -o HPOption_Tray4=HP520SheetInputTray
	${lpa} -p  PRINTER1 -o HPOption_Tray5=HP520SheetInputTray
	;;

Printer2)
	
	${lpa} -p  PRINTER2 -E -o printer-is-shared=false -v ipp://10.1.1.2 -D "PRINTER2" -P "/Library/Printers/PPDs/Contents/Resources/HP Color MFP E87640-50-60.gz"
	${lpa} -p  PRINTER2 -o HPOption_Tray4=HP520SheetInputTray
	${lpa} -p  PRINTER2 -o HPOption_Tray5=HP520SheetInputTray

	;;
	
	Office) ## or a group of printers for an office
	
	${lpa} -p  PRINTER1 -E -o printer-is-shared=false -v ipp://10.1.1.1 -D "PRINTER1" -P "/Library/Printers/PPDs/Contents/Resources/HP Color MFP E87640-50-60.gz"
	${lpa} -p  PRINTER1 -o HPOption_Tray4=HP520SheetInputTray
	${lpa} -p  PRINTER1 -o HPOption_Tray5=HP520SheetInputTray
	
	${lpa} -p  PRINTER2 -E -o printer-is-shared=false -v ipp://10.1.1.2 -D "PRINTER2" -P "/Library/Printers/PPDs/Contents/Resources/HP Color MFP E87640-50-60.gz"
	${lpa} -p  PRINTER2 -o HPOption_Tray4=HP520SheetInputTray
	${lpa} -p  PRINTER2 -o HPOption_Tray5=HP520SheetInputTray
		
esac

exit 0