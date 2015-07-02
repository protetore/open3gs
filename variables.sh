#!/bin/bash

PROVIDERS_DIR="providers.d"
CONF_DIR="conf.d"
WVDIAL_DIR="wvdial.d"
DEPENDENCIES=(wvdial,pppd,usb_modeswitch,chat,stty)
LOG_DIR=/var/log/open3gs

OP=""
MODEM=/dev/ttyUSB0
CHAT_OPTS="-v TIMEOUT 300 ABORT \"BUSY\" ABORT \"NO DIALTONE\" ABORT \"NO CARRIER\" \"\" ATZ OK AT+cfun=1 OK AT+CGDCONT=1,\"IP\",\"__APN__\" -T ATDT__ATD__ CONNECT \"\""
PPP_OPTS="-d __MODEM__ 460800 noauth persist defaultroute noipdefault usepeerdns nodeflate refuse-pap user __USR__ password __PWD__ connect"

# EXEC
CAT=$(which cat)
ECHO=$(which echo)
GREP=$(which grep)
SED=$(which sed)
HEAD=$(which head)
AWK=$(which awk)
RM=$(which rm)
PRINTF=$(which printf)
LN=$(which ln)
TR=$(which tr)
PS=$(which ps)
WC=$(which wc)
MKDIR=$(which mkdir)
CHAT=$(which chat)
STTY=$(which stty)
KILLALL=$(which killall)
KILL=$(which kill)
WVDIAL=$(which wvdial)
PPPD=$(which pppd)
