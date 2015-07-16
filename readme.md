#open3gs

Based on the Open3G project. This script was written to allow an embedded Linux system using Raspberry PI to connect to the Internet using a 3G modem. It can handle disconnection, can auto detect APN and optionally can use wvdial to handle the connection. 

#Required Packages

1. pppd
2. wvdial [optional use]
3. usb_modeswitch
4. chat
5. stty


#Usage

##Command:

**open3gs [options]**

 -i         *First step: create link to bin, logs dir, configure logrotate, detect modem, carrier...*
 -s         *Status of the connection*
 -c         *Connect to the auto-detected carrier*
 -d         *Close active connection*
 -r         *Finishes the actual connection/process and try to connect again.*
 -n         *Detect the modem and APN and build the default configuration file.*
 -a         *Always detect modem, APN, configure the modem when dialing. (Use with the -c option)*
 -e         *Experimental dialing option. Don't use wvdial or other third party tools, use only pppd and basic linux tools.*
 -f         *Force to use a specific config file. (Use with -n or -c options).*
 -h         *Display this screen*

##Examples:

>open3gs -c -f                                    #connect using settings created by 'open3gs -i' or 'open3gs -n'
open3gs -c -f /opt/open3gs/providers.d/oi.conf   #connect using specific config file
open3gs -c -a                                    #aways try to detect carrier and modem when dialing
open3gs -n                                       #config open3gs auto-detecting settings
open3gs -n -f /opt/open3gs/providers.d/oi.conf   #config open3gs to use specific config file


#Reminders

1. Sample pppd:

/usr/sbin/pppd -d /dev/ttyUSB0 460800 noauth persist defaultroute noipdefault usepeerdns nodeflate refuse-pap user oi password oi connect /usr/bin/chat -v TIMEOUT 300 ABORT \BUSY\ ABORT \NO DIALTONE\ ABORT \NO CARRIER\ \\ ATZ OK AT+cfun=1 OK AT+CGDCONT=1,\IP\,\gprs.oi.com.br\ -T ATDT*99# CONNECT \\

2. Connect with wvdial:

/usr/bin/wvdial -C /specta/3g/default.conf
