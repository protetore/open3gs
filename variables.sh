#!/bin/bash

OP=""
PROVIDERS_DIR="providers.d"
CONF_DIR="conf.d"
DEPENDENCIES=(wvdial,pppd,usb_modeswitch,chat)
LOG_DIR=/var/log/open3gs

# EXEC
CAT=$(/usr/bin/which cat)
ECHO=$(/usr/bin/which echo)
GREP=$(/usr/bin/which grep)
SED=$(/usr/bin/which sed)
AWK=$(/usr/bin/which awk)
RM=$(/usr/bin/which rm)
LN=$(/usr/bin/which ln)
CHAT=$(/usr/bin/which chat)
KILLALL=$(/usr/bin/which killall)
