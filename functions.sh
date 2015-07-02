#!/bin/bash
#
# Open3G Shell Version
# title           :open3gs
# file            :functions.sh
# description     :Functions to setup modem and handle connection
# author          :protetore
# date            :20150621
# version         :0.1
# bash_version    :4.1.5(1)-release
#=============================================================

BASE_DIR=$(dirname $(/bin/readlink -f $0))
. $BASE_DIR/variables.sh

checkDependencies()
{
    retval=0;

    IFS=","
    for dep in $DEPENDENCIES
    do
        if [ ! $(/usr/bin/which $dep) ];
        then
            $ECHO "ERROR: Dependency no found: $dep"
            retval=1
        fi
    done

    return $retval
}

modemAttached()
{
    # Find where modem is
    attachedDevice=$(dmesg | $GREP GSM | $GREP attached | $AWK '{ print $12 }' | $HEAD -1)
    if [ "$attachedDevice" == "" ];
    then
        $ECHO "ERROR: Modem not found. (1)";
        return 1;
    fi

    if [ ! -f "/dev/$attachedDevice" ];
    then
        $ECHO "ERROR: Modem not found. (2)";
        return 1;
    fi

    MODEM=/dev/$attachedDevice

    return 0;
}

checkModem()
{
    # Find where modem is
    attachedDevice=$(dmesg | $GREP GSM | $GREP attached | $AWK '{ print $12 }' | $HEAD -1)
    if [ "$attachedDevice" == "" ];
    then
        $ECHO "ERROR: Modem not found. (1)";
        return 1;
    fi

    if [ ! -c "/dev/$attachedDevice" ];
    then
        $ECHO "ERROR: Modem not found. (2)";
        return 1;
    fi

    $ECHO "INFO: Modem found in /dev/$attachedDevice"
    MODEM=/dev/$attachedDevice

    # Connect to the modem and capture the apn
    # Initialize modem
    $STTY -F $MODEM 9600
    # Listen to its output
    $RM -f $LOG_DIR/modem.out
    $CAT $MODEM > $LOG_DIR/modem.out &
    catPid=$?
    # Send some basic commands
    $ECHO "AT" > $MODEM
    $ECHO "AT+CFUN=1" > $MODEM
    $ECHO "AT+COPS=3,0" > $MODEM
    $ECHO "AT+COPS?" > $MODEM
    # Kill cat session
    $KILL $catPid
    # Read modem response
    apnCode=$($CAT $LOG_DIR/modem.out)
    apnCode=$($ECHO "$apnCode" | $GREP "+COPS:" | $AWK -F"," '{ print $3 }' | $SED -e 's/"//g')

    if [ "$apnCode" == "" ];
    then
        $ECHO "ERROR: APN could not be detected! Modem sent an empty reply.";
        return 1;
    fi

    $confFile=$($GREP -l "COD=$apnCode" -r $BASE_DIR/$PROVIDERS_DIR/*.conf)

    if [ "$confFile" == "" ];
    then
        $ECHO "ERROR: No config file for APN: $apnCode in $BASE_DIR/$PROVIDERS_DIR/";
        return 1;
    fi

    OP=$(basename $conFile)
    OP=$($ECHO ${OP%.conf})

    return 0;
}

reconfigure()
{
    retval=0

    if [ ! "$1" ==  "" ];
    then
        $ECHO "@ Loadind specific config..."
        confFile=$1
    else
        $ECHO "@ Checking modem..."
        checkModem
        if [ "$?" == "1" ];
        then
            exit 1
        fi

        confFile=$BASE_DIR/$PROVIDERS_DIR/$OP.conf
    fi

    $RM -f $BASE_DIR/$WVDIAL_DIR/default.conf
    $RM -f $BASE_DIR/$CONF_DIR/chat_default.conf
    $RM -f $BASE_DIR/$CONF_DIR/ppp_default.conf

    if [ \( ! -f $confFile \) -a \( ! -f $BASE_DIR/$PROVIDERS_DIR/$confFile \) ];
    then
        $ECHO "ERROR: Config file $confFile not found!"
        exit 1;
    fi

    #IFS="\n"
    #confs=( $(cat "$BASE_DIR/$PROVIDERS_DIR/$OP.conf") )
    #for conf in $confs
    #do
    #    echo $conf
    #done

    APN=$($GREP -m 1 APN "$confFile" | $SED '/^#.*$/d; s/APN=//')
    USR=$($GREP -m 1 USR "$confFile" | $SED '/^#.*$/d; s/USR=//')
    PWD=$($GREP -m 1 PWD "$confFile" | $SED '/^#.*$/d; s/PWD=//')
    ATD=$($GREP -m 1 ATD "$confFile" | $SED '/^#.*$/d; s/ATD=//')
    COD=$($GREP -m 1 COD "$confFile" | $SED '/^#.*$/d; s/COD=//')

    if [ "$APN" == "" ];
    then
        $ECHO "ERROR: No APN (apn url) setting in $confFile!"
        retval=1
    fi

    if [ "$USR" == "" ];
    then
        $ECHO "ERROR: No USR (user) setting in $confFile!"
        retval=1
    fi

    if [ "$PWD" == "" ];
    then
        $ECHO "ERROR: No PWD (password) setting in $confFile!"
        retval=1
    fi

    if [ "$ATD" == "" ];
    then
        $ECHO "ERROR: No ATD (phone to dial) setting in $confFile!"
        retval=1
    fi

    if [ "$COD" == "" ];
    then
        $ECHO "ERROR: No COD (operator code) setting in $confFile!"
        retval=1
    fi

    if [ "$retval" == "1" ];
    then
        exit 1
    fi

    if [ ! -f $BASE_DIR/$CONF_DIR/pppd.conf ];
    then
        $ECHO "ERROR: PPPD config file $BASE_DIR/$CONF_DIR/pppd.conf not found!"
        exit 1;
    fi

    PPP_OPTS=$($CAT $BASE_DIR/$CONF_DIR/pppd.conf | $TR '\n' ' ')
    PPP_OPTS=$($ECHO $PPP_OPTS | $SED "s|__MODEM__|$MODEM|g" | $SED "s/__USR__/$USR/g" | $SED "s/__PWD__/$PWD/g")

    if [ ! -f $BASE_DIR/$CONF_DIR/chat.conf ];
    then
        $ECHO "ERROR: CHAT config file $BASE_DIR/$CONF_DIR/chat.conf not found!"
        exit 1;
    fi

    CHAT_OPTS=$($CAT $BASE_DIR/$CONF_DIR/chat.conf | $TR '\n' ' ')
    CHAT_OPTS=$($ECHO $CHAT_OPTS | $SED "s/__APN__/$APN/g" | $SED "s/__ATD__/$ATD/g")

    $ECHO $CHAT_OPTS > $BASE_DIR/$CONF_DIR/chat_default.conf
    $ECHO $PPP_OPTS > $BASE_DIR/$CONF_DIR/ppp_default.conf

    if [ ! -f $BASE_DIR/$WVDIAL_DIR/template.conf ];
    then
        $ECHO "INFO: No template found. Using default settings..."

        # $CAT > $BASE_DIR/$WVDIAL_DIR/template.conf <<- END_CFG
        #     [Dialer Defaults]
        #     Init1 = ATZ
        #     Init2 = ATQ0 V1 E1 S0=0 &C1 &D2 +FCLASS=0
        #     Init3 = AT+CGDCONT=1,"IP","__APN__"
        #     Modem Type = Analog Modem
        #     Phone = __ATD__
        #     ISDN = 0
        #     Username = __USR__
        #     Password = __PWD__
        #     Modem = __MODEM__
        #     Baud = 460800
        #     New PPPD = yes
        #     Stupid Mode = yes
        #     DialCommand = ATDT
        #     Check Def Route = on
        #     FlowControl = Hardware(CRTSCTS)
        #     Auto Reconnect = on
        #     Auto DNS = on
        #     Abort on Busy = off
        #     Carrier Check = off
        #     Abort on No Dialtone = off
        #     END_CFG
    fi

    WVDIAL_OPTS=$($CAT $BASE_DIR/$WVDIAL_DIR/template.conf)
    WVDIAL_OPTS=$($ECHO $WVDIAL_OPTS | $SED "s|__MODEM__|$MODEM|g" | $SED "s/__USR__/$USR/g" | $SED "s/__PWD__/$PWD/g" | $SED "s/__APN__/$APN/g" | $SED "s/__ATD__/$ATD/g")
    $ECHO "$WVDIAL_OPTS" > $BASE_DIR/$WVDIAL_DIR/default.conf;

    $ECHO "@ Finished configuring."
    return $retval;
}

install()
{
    $ECHO "@ SETUP"
    $ECHO "@ Checking dependencies..."

    checkDependencies
    if [ "$?" == "1" ];
    then
        exit 1
    fi

    $ECHO "@ Checking scripts..."
    if [ "$0" == "/usr/bin/open3gs" ];
    then
            echo "ERROR: Setup function must be called from the sh script not from the link in /usr/bin/"
            echo "Call: $BASE_DIR/open3gs setup"
            exit 1
    fi

    $ECHO "@ Configuring logrotate..."
    if [ -d /etc/logrotate.d ];
    then
        if [ -f /etc/logrotate.d/vpn ];
        then
                $ECHO "INFO: Previous logrotate file found. Erasing it..."
                $RM -f /etc/logrotate.d/open3gs
        fi

        # $CAT > /etc/logrotate.d/open3gs <<- END_CFG
        #     $LOG_DIR/*log {
        #         missingok
        #         notifempty
        #         size 30k
        #         monthly
        #         create 0600 root root
        #     }
        #     END_CFG
    else
            $ECHO "INFO: Logrotate not found. Log will grow without supervision in $LOG_DIR"
    fi

    $ECHO "@ Creating logs directory..."
    if [ ! -d $LOG_DIR ];
    then
            $MKDIR $LOG_DIR
    else
            $ECHO "INFO: Logs directory already exists. Skipping..."
    fi

    if [ ! -h /usr/bin/open3gs  ];
    then
            $ECHO "@ Linking open3gs script to /usr/bin/..."
            SCRIPT_PATH=$(/bin/readlink -f $0)
            $LN -s $SCRIPT_PATH /usr/bin/open3gs
    fi

    $ECHO "@ Detectiong modem and configuring defaut settings..."
    reconfigure
    if [ "$?" == "1" ];
    then
        exit 1
    fi

    $ECHO "@ Finished configuring Open3Gs."
    $ECHO
    usage
}

initConn()
{
    $ECHO "@ Activating modem..."
    # Initialize modem
    $STTY -F $MODEM 9600
    # Listen to its output
    $RM -f $LOG_DIR/modem.out
    $CAT $MODEM > $LOG_DIR/modem.out &
    catPid=$?
    # Send some basic commands
    $ECHO "AT" > $MODEM
    $ECHO "AT+CFUN=1" > $MODEM
    # Kill cat session
    $KILL $catPid

    $ECHO "@ Setting up first modem connection..."
    # Calling pppd to initialize whatever is needed by the modem
    chatOpts=$($CAT $BASE_DIR/$CONF_DIR/chat_default.conf)
    pppdOpts=$($CAT $BASE_DIR/$CONF_DIR/ppp_default.conf)
    chatOpts=$($ECHO $chatOpts | $SED 's/\"/\\\"/g')

    #eval "$PPPD $pppdOpts \"$CHAT -v $chatOpts\""
    command=($PPPD $pppdOpts "\"$CHAT -v $chatOpts\"")
    "${command[@]}"
    cmdPid=$!
    sleep 5
    $KILL -9 $cmdPid

    return 0
}

wvdial()
{
    if [ ! -f $BASE_DIR/$WVDIAL_DIR/default.conf ];
    then
        $ECHO "ERROR: WVDial default.conf config file not found. Run 'open3gs -r' or 'open3gs -i'. (3)"
        exit 1
    else
        $ECHO "INFO: Using default wvdial file. You can reconfigure with 'open3gs -r'."
    fi

    initConn

    $ECHO "@ Dialing..."
    nohup $WVDIAL -C $BASE_DIR/$WVDIAL_DIR/default.conf > $LOG_DIR/open3gs.log 2>&1 &

    return 0
}

openDial()
{
    initConn

    # Calling pppd to initialize whatever is needed by the modem
    chatOpts=$($CAT $BASE_DIR/$CONF_DIR/chat_default.conf)
    pppdOpts=$($CAT $BASE_DIR/$CONF_DIR/ppp_default.conf)
    chatOpts=$($ECHO $chatOpts | $SED 's/\"/\\\"/g')

    #eval "$PPPD $pppdOpts \"$CHAT -v $chatOpts\""
    command=($PPPD $pppdOpts "\"$CHAT -v $chatOpts\"")
    "${command[@]}"
    cmdPid=$!

    nohup connWatcher $cmdPid > $LOG_DIR/open3gs.log 2>&1 &

    exit 0
}

connWatcher()
{
    if [ "$1" == "" ];
    then
        $ECHO "ERROR: No PID to watch. Exiting now..."
        exit 1
    fi

    while :
    do
        procNum=$($PS -ef | $GREP -v "grep" | $GREP "$1" | $GREP "pppd" | $WC -l)

        if [ $procNum -eq 0 ];
        then
            $ECHO "INFO: pppd process (PID $1) not found. Dialing again..."
            openDial
            exit 0
        fi

        sleep 3
    done
}

connect()
{
    checkDependencies
    if [ "$?" == "1" ];
    then
        exit 1
    fi

    modemAttached
    if [ "$?" == "1" ];
    then
        exit 1
    fi

    if [ "$1" == "0" ];
    then
        reconfigure
        if [ ! $? ];
        then
            exit 1
        fi
    fi

    if [ ! "$2" == "" ];
    then
        reconfigure $2
        if [ ! $? ];
        then
            exit 1
        fi
    fi

    if [ ! -f $BASE_DIR/$CONF_DIR/chat_default.conf ];
    then
        $ECHO "ERROR: Config file not found. Run 'open3gs -r' or 'open3gs -i'. (1)"
        exit 1
    fi

    if [ ! -f $BASE_DIR/$CONF_DIR/ppp_default.conf ];
    then
        $ECHO "ERROR: Config file not found. Run 'open3gs -r' or 'open3gs -i'. (2)"
        exit 1
    fi

    if [ "$3" == "0" ];
    then
        $ECHO "@ Using experimental connection mode (no third party dialer)..."
        openDial
    else
        $ECHO "@ Using wvdial to control connection.."
        wvdial
    fi

    $ECHO "@ Connection active. Output can be found in $LOG_DIR/open3gs.log"
}

disconnect()
{
    $ECHO "@ Stopping active connection..."
    $KILLALL -9 wvdial
    $KILLALL -9 pppd

    scriptName=$(basename "$0")
    procPid=$($PS -ef | $GREP -v "grep" | $GREP "$scriptName" | $AWK '{ print $2 }')
    $KILL -9 $procPid
}

reconnect()
{
    $ECHO "@ Disconnecting..."
    disconnect
    sleep 2
    $ECHO "@ Reconnecting..."
    connect $1 $2 $3
}

connStatus()
{
    $ECHO "Work in progress.."
}

usage()
{
    echo
    echo ">> Usage: open3gs [option|optional]"
    echo
    echo " -i         First step: create link to bin, logs dir, configure logrotate, detect modem, carrier..."
    echo " -s         Status of the connection"
    echo " -c         Connect to the auto-detected carrier"
    echo " -d         Close active connection"
    echo " -r         Finishes the actual connection/process and try to connect again."
    echo " -n         Detect the modem and APN and build the default configuration file."
    echo " -a         Always detect modem, APN, configure the modem when dialing. (Use with the -c option)"
    echo " -e         Experimental dialing option. Don't use wvdial or other third party tools, use only pppd and basic linux tools."
    echo " -f         Force to use a specific config file. (Use with -n or -c options)."
    echo " -h         Display this screen"
    echo
    echo "---------"
    echo "Examples: "
    echo "---------"
    echo "open3gs -c -f                                    #connect using settings created by 'open3gs -i' or 'open3gs -n'"
    echo "open3gs -c -f /opt/open3gs/providers.d/oi.conf   #connect using specific config file"
    echo "open3gs -c -a                                    #aways try to detect carrier and modem when dialing"
    echo "open3gs -n                                       #config open3gs auto-detecting settings"
    echo "open3gs -n -f /opt/open3gs/providers.d/oi.conf   #config open3gs to use specific config file"
    echo
}
