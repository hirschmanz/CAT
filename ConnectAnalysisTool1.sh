#!/bin/bash

####################################################################################################
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# 		BY USING THIS SCRIPT, YOU AGREE THAT JAMF SOFTWARE
# 		IS UNDER NO OBLIGATION TO SUPPORT, DEBUG, OR OTHERWISE
# 		MAINTAIN THIS SCRIPT
#
#
#####################################################################################################
#
# DESCRIPTION
#
# This script gathers comprehensive information from a Mac about its Jamf Connect settings and behavior, and puts it in a single local txt file.
#
#
####################################################################################################
#
# HISTORY
#.6 adds license info
#.7 adds kerberos and authchanger plist
#.8 adds: LaunchAgent detection
#
#.9 plan: clean up the plists for a 1.0 release
# CAT version 1 created Nov/Dec 2021 by Zac Hirschman at github dot com slash hirschmanz
#
# /\_/\
#( z z )
# > Y <
# 
####################################################################################################
#
# SYNOPSIS - How to use
#	
# Execute the script locally in terminal or deployed via policy from Jamf Pro
# The output file location can be customized in the LOGMEOW variable 
#
# Results are appended and do not overwrite an existing log file
#
####################################################################################################

#Log file creation
currentUser=$( /usr/bin/stat -f "%Su" /dev/console )
serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
LOGMEOW="/Users/$currentUser/Desktop/CAT-$serial.txt"

if [ ! -e $LOGMEOW ]; then
touch $LOGMEOW
fi

###############
#INPUT SECTION#
###############

#Input Mac information
MacOS_version=$(sw_vers -productVersion)

#Input plists
###Improvement potential: formatting. tr is a machete, not a scalpel
##Login 
if [ -e /Library/Managed\ Preferences/com.jamf.connect.login.plist ]; then
Login_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.login.plist" | sed 's/ =     {/:/' | tr -d "};")
else
Login_plist="Login plist not found"
fi
##Menubar 
if [ -e /Library/Managed\ Preferences/com.jamf.connect.plist ]; then
Menubar_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.plist" | sed 's/ =     {/:/' | tr -d "};")
else
Menubar_plist="Menubar plist not found"
fi
##Actions
if [ -e /Library/Managed\ Preferences/com.jamf.connect.actions.plist ]; then
Actions_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.actions.plist" | sed 's/ =     {/:/' | tr -d "};")
else
Actions_plist="No deployed Actions plist"
fi
##Shares
if [ -e /Library/Managed\ Preferences/com.jamf.connect.shares.plist ]; then
Shares_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.shares.plist" | sed 's/ =     {/:/' | tr -d "};")
else
Shares_plist="No deployed Shares plist"
fi
##state plist
State_plist=$(su "$currentUser" -c "defaults read com.jamf.connect.state" 2>/dev/null)
if [[ -z "$State_plist" ]]; then
State_plist="No user is currently logged in to Menubar"
fi
##authchanger plist
if [ -e /Library/Managed\ Preferences/com.jamf.connect.authchanger.plist ]; then
Auth_plist=$(defaults read "/Library/Managed Preferences/com.jamf.connect.authchanger.plist" | sed 's/ =     {/:/' | tr -d "};")
else
Auth_plist="No deployed Authchanger plist"
fi
##LaunchAgent
if [ -e /Library/LaunchAgents/com.jamf.connect.plist ]; then
Launch_Agent=$(defaults read /Library/LaunchAgents/com.jamf.connect.plist | sed 's/ =     {/:/' | tr -d "};")
else
Launch_Agent="No LaunchAgent Detected"
fi

#input logs
Login_log=$(cat /private/tmp/jamf_login.log /dev/null 2>&1)
Menubar_log=$(log show --style compact --predicate 'subsystem == "com.jamf.connect"' --debug --last 30m)

#input authchanger
loginwindow_check=$`security authorizationdb read system.login.console > /dev/null 2>&1 | grep 'loginwindow:login'`

#input curb rose
kerblist=$(su "$currentUser" -c "klist 2>&1")
if [[ "$kerblist" == "" ]];then
kerblist="No tickets"
fi

#input versions
jamfConnectLoginLocation="/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle"
jamfConnectLoginVersion=$(defaults read "$jamfConnectLoginLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null)
jamfConnectLocation="/Applications/Jamf Connect.app"
jamfConnectVersion=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleShortVersionString" 2>/dev/null)

#License Input Section - credit Casey Utke

# input encoded license files
LicensefromLogin=$(defaults read /Library/Managed\ Preferences/com.jamf.connect.login.plist LicenseFile 2>/dev/null)
LicensefromMenubar=$(defaults read /Library/Managed\ Preferences/com.jamf.connect.plist LicenseFile 2>/dev/null) 
if [[ "$LicensefromLogin" == "PD94"* ]]; then
file=$(echo "$LicensefromLogin" | base64 -d)
elif [[ "$LicensefromMenubar" == "PD94"* ]]; then
file=$(echo "$LicensefromMenubar" | base64 -d)
else
file=""
fi
# Grabs and formats data from input file
dat=$`echo "$file" | awk '/ExpirationDate/ {getline;print;exit}' | tr -d '<string>' | tr -d '</string>'`
name=$`echo "$file" | awk '/Name/ {getline;print;exit}' | tr -d '<string>' | tr -d '</string>'`
num=$`echo "$file" | awk '/NumberOfClients/ {getline;print;exit}' | tr -d '<integer>' | tr -d '</integer>'`


################ 
#OUTPUT SECTION#
################


#human readable header
echo "Begin Cat" >> $LOGMEOW
echo "CAT Output created on: "`date` >> $LOGMEOW
echo "=============Begin CAT============================" >> $LOGMEOW

#versions

echo "MacOS version:                $MacOS_version" >> $LOGMEOW

if [ ! -e $jamfConnectLoginLocation ]; then
echo "Jamf Connect Login not found" >> $LOGMEOW
else
echo "Jamf Connect Login version:   $jamfConnectLoginVersion" >> $LOGMEOW
fi

if [ ! -e "$jamfConnectLocation" ]; then
echo "Jamf Connect Menubar not found" >> $LOGMEOW
else
echo "Jamf Connect Menubar version: $jamfConnectVersion" >> $LOGMEOW
fi


#authchanger
if [ $loginwindow_check="" ]; then
echo "authchanger is presenting the MacOS Login Window" >> $LOGMEOW
else
echo "authchanger is presenting the Jamf Connect Login Window" >> $LOGMEOW
fi

#Outputs account name, expiration date, and number of Jamf Connect licenses if found
echo "====================================================" >> $LOGMEOW
echo "License Information:" >> $LOGMEOW

if [ "$file" != "" ]; then
echo "        Account:" "$name" >> $LOGMEOW
echo "Expiration Date:" "$dat" >> $LOGMEOW
echo "Number of Seats:" "$num" >> $LOGMEOW
else
echo "License not found" >> $LOGMEOW
fi


#output plists
echo "====================================================" >> $LOGMEOW
echo "Full Property Lists:" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Login Plist" >> $LOGMEOW
echo "$Login_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Menubar Plist" >> $LOGMEOW
echo "$Menubar_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "State Plist" >> $LOGMEOW
echo "$State_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Actions Plist" >> $LOGMEOW
echo "$Actions_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Shares Plist" >> $LOGMEOW
echo "$Shares_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "Authchanger Plist" >> $LOGMEOW
echo "$Auth_plist" >> $LOGMEOW
echo "-------------" >> $LOGMEOW
echo "LaunchAgent:" >> $LOGMEOW
echo "$Launch_Agent" >> $LOGMEOW


#output klist and krb5.conf files:
##improvement potential - logic to check for preferences first
echo "====================================================" >> $LOGMEOW
echo "Kerberos:" >> $LOGMEOW
echo " $kerblist" >> $LOGMEOW
if [ -e /etc/krb5.conf ]; then
echo "krb5.conf file in place" >> $LOGMEOW
else
echo "no krb5.conf file in place" >> $LOGMEOW
fi

#output logs
echo "====================================================" >> $LOGMEOW
if [ $loginwindow_check!="" ]; then
echo "Login log from last login:" >> $LOGMEOW
echo "$login_log" >> $LOGMEOW
fi
echo "-------------" >> $LOGMEOW
echo "Menubar Log (last 30 minutes):" >> $LOGMEOW
echo "$Menubar_log" >> $LOGMEOW
echo "=============CAT complete==========================" >> $LOGMEOW
