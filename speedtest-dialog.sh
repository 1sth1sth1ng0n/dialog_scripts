#!/bin/bash

#===============================================================================
#          FILE: speedtest-dialog.sh
#         USAGE: jamf policy
#   DESCRIPTION: uses dialog app to start speedtest.py
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: managed python framework required
#        AUTHOR: oliver.reardon
#  ORGANIZATION: 
#       CREATED: 15012022 09:50
#      REVISION:  0.7
#===============================================================================

DialogLog='/var/tmp/dialog.log'
width='600'
height='250'
titlefontsize='size=25'
message1='Check your internet speed in under 30 seconds.  \n\nTo perform an accurate test please follow these steps first:  \n\n
\n- Close all open applications.\n- Find a location that provides a reliable Wi-Fi signal.\n- Confirm no other users on the same network are streaming content (i.e Netflix).'
message2='Checking internet latency and speed.....  \n\n.....please wait.'

# function to write commands to dialog command file
function writeDialogCommands() {
    /bin/echo "$1" >> /var/tmp/dialog.log
}

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    # else # uncomment this else if you want your script to exit now if swiftDialog is not installed
      # displayAppleScript # uncomment this if you're using my displayAppleScript function
      # echo "Dialog Team ID verification failed."
      # exit 1
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
  else echo "Dialog found. Proceeding..."
  fi
}

function dialog1(){
/usr/local/bin/dialog \
-o \
--height ${height} \
--width ${width} \
--icon '/usr/local/blob/logo-400-border.png'  \
--button1text "Start" \
--button2text "Quit" \
--title 'Speed Test Utility' \
--titlefont ${titlefontsize} \
--message ${message1} \
--messagefont "size=14" \
--iconsize 100
}

function dialog2(){

/usr/local/bin/dialog \
-o \
--height ${height} \
--width ${width} \
--icon '/usr/local/blob/logo-400-border.png'  \
--button1text "Quit" \
--progress \
--title 'Speed Test Utility' \
--titlefont ${titlefontsize} \
--message ${message2} \
--messagefont "size=14" \
--iconsize 100 &

# need this sleep to let the dialog app open as it deletes the command file on launch
sleep 1

# we don not want the OK button to do anything here
/bin/echo "button1: disable" >> /var/tmp/dialog.log

# we want the output to not get buffered, the -u forces sed to not use buffering
# we need to use a managed python framework in all recent versions of macos
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | \
/Library/ManagedFrameworks/Python/Python3.framework/Versions/Current/bin/python3 - \
| sed -u -e 's/^/progressText: /' >> "$DialogLog"
}

function dialog3(){

# wait for speed test to complete
while [[ ! $ulcheck ]]; do
  ulcheck=$(cat /var/tmp/dialog.log | grep 'Upload:')
  sleep 1
done

# some logic to report dl/ul human readable terms
dl=$(cat /var/tmp/dialog.log | grep 'Download:' | awk '{print $3}')
if [[ $dl -ge 100 ]];then
  dl="${dl}Mbits/s (Excellent)"
elif [[ $dl -le 99 ]]; then
  dl="${dl}Mbits/s (Good)"
elif [[ $dl -le 50 ]]; then
  dl="${dl}Mbits/s (Average)"
elif [[ $dl -le 10 ]]; then
  dl="${dl}Mbits/s (Low)"
else
  dl="${dl}Mbits/s (Very Low)"
fi

ul=$(cat /var/tmp/dialog.log | grep 'Upload:' | awk '{print $3}')
if [[ $ul -ge 100 ]];then
  ul="${ul}Mbits/s (Excellent)"
elif [[ $ul -le 99 ]]; then
  ul="${ul}Mbits/s (Good)"
elif [[ $ul -le 50 ]]; then
  ul="${ul}Mbits/s (Average)"
elif [[ $ul -le 10 ]]; then
  ul="${ul}Mbits/s (Low)"
else
  ul="${ul}Mbits/s (Very Low)"
fi

# hosted by data
#hb=$(cat /var/tmp/dialog.log | grep 'Hosted by' | awk '{print $4,$5,$6,$7,$8,$9}')
# ip data
tf=$(cat /var/tmp/dialog.log | grep 'Testing from' | awk '{print $4,$5,$6}')

message3="Results:  \n\nTesting from: **${tf}**  \nDownload Speed = **${dl}**  \nUpload Speed = **${ul}**  \n\nPlease contact the help desk for assistance with your internet speed - help@help.com."

/usr/local/bin/dialog \
-o \
--height ${height} \
--width ${width} \
--icon '/usr/local/blob/logo-400-border.png'  \
--button1text "OK" \
--button2text "Submit to help" \
--title 'R/GA - Speed Test Utility' \
--titlefont ${titlefontsize} \
--message ${message3} \
--messagefont "size=14" \
--iconsize 100

# send details to help
if [[ $? == '2' ]]; then
  /usr/bin/open mailto:"help@help.com?subject=HelpDesk Issue - Reported via Company Menu Utility from $(/bin/hostname)&body=I need help with internet speed. Speed Test Results: DL = ${dl}Mbps, UL = ${ul}Mbps"
fi
} 

# main process
dialogCheck
dialog1

case $? in
  0)
  writeDialogCommands "quit:"
  # Button 1 processing here
  dialog2
  writeDialogCommands "quit:"
  dialog3
  ;;
  2)
  # Button 2 processing here
  writeDialogCommands "quit:"
  ;; 
  *)
  echo "Failed to make a selection"
  ;;
esac
