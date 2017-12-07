# open3gs

Based on the Open3G project. This script was written to allow an embedded Linux system using Raspberry PI to connect to the Internet using a 3G modem. It can handle disconnection, can auto detect APN and optionally can use wvdial to handle the connection.

# Requirements

1. pppd
2. wvdial **[optional use]**
3. usb_modeswitch
4. chat
5. stty

**Obs**: On debian run `apt install wvdial ppp usb-modeswitch`

# Usage

**open3gs [COMMAND] [OPTIONS]**

Command     | Details
----------- | ---------------------------------------------------------------------------------------
install     | First step: create link to bin, logs dir, configure logrotate, detect modem, carrier...
connect     | Connect to the auto-detected carrier
disconnect  | Close active connection
reconnect   | Finishes the actual connection/process and try to connect again
status      | Display the status of the current connection
reconfigure | Detect the modem and APN and build the default configuration file
help        | Display this help

Option | Details
------ | ------------------------------------------------------------------------------------------
-a     | Always detect modem, APN, configure the modem when dialing. (use with `connect`)
-e     | Experimental option. Don't use wvdial, use only pppd and basic linux tools (for `connect`)
-f     | Force to use a specific config file. (Use with `connect` or `reconfigure`)

# Examples:

```
open3gs connect -f                                      # connect with settings created by 'install' or 'reconfigure'
open3gs connect -f /etc/open3gs/providers.d/oi.conf     # connect using specific config file
open3gs connect -a                                      # aways try to detect carrier and modem when dialing
open3gs reconfigure                                     # config open3gs auto-detecting settings
open3gs reconfigure -f /opt/open3gs/providers.d/oi.conf # config open3gs to use specific config file
```

# Reminders

1. Sample pppd:

  ```
  /usr/sbin/pppd -d /dev/ttyUSB0 460800 noauth persist defaultroute noipdefault usepeerdns nodeflate refuse-pap user oi password oi connect /usr/bin/chat -v TIMEOUT 300 ABORT \BUSY\ ABORT \NO DIALTONE\ ABORT \NO CARRIER\ \\ ATZ OK AT+cfun=1 OK AT+CGDCONT=1,\IP\,\gprs.oi.com.br\ -T ATDT*99# CONNECT \\
  ```

2. Connect with wvdial:

  ```
  /usr/bin/wvdial -C /specta/3g/default.conf
  ```
