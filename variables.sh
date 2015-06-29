#!/bin/bash

PROVIDERS_DIR="providers.d"
CONF_DIR="conf.d"
DEPENDENCIES=(wvdial,pppd,usb_modeswitch,chat)
LOG_DIR=/var/log/open3gs

OP=""
MODEM=/dev/ttyUSB0
CHAT_OPTS="-v TIMEOUT 300 ABORT \"BUSY\" ABORT \"NO DIALTONE\" ABORT \"NO CARRIER\" \"\" ATZ OK AT+cfun=1 OK AT+CGDCONT=1,\"IP\",\"__APN__\" -T ATDT__ATD__ CONNECT \"\""
PPP_OPTS="-d __MODEM__ 460800 noauth persist defaultroute noipdefault usepeerdns nodeflate refuse-pap user __USR__ password __PWD__ connect"

# EXEC
CAT=$(/usr/bin/which cat)
ECHO=$(/usr/bin/which echo)
GREP=$(/usr/bin/which grep)
SED=$(/usr/bin/which sed)
HEAD=$(/usr/bin/which head)
AWK=$(/usr/bin/which awk)
RM=$(/usr/bin/which rm)
PRINTF=$(/usr/bin/which printf)
LN=$(/usr/bin/which ln)
TR=$(/usr/bin/which tr)
CHAT=$(/usr/bin/which chat)
KILLALL=$(/usr/bin/which killall)
