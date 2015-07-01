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
    # Listen to its output
    $CAT $MODEM | $GREP "+COPS:" | $AWK -F"," '{ print $3 }' | $SED -e 's/"//g' > $LOG_DIR/modem.out &
    # Send some basic commands
    $CHAT -V -s '' 'AT' '' 'AT+CFUN=1' '' 'AT+COPS=3,0' '' 'AT+COPS?' '' > $MODEM < $MODEM
    sleep 1;
    # Kill chat session
    $KILLALL -9 cat
    # Reading modem response
    apnCode=$($CAT $LOG_DIR/modem.out)

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

setup()
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

    if [ "$1" == "1" ];
    then
        reconfigure
        if [ ! $? ];
        then
            exit 1
        fi
    fi

    if [ ! -f $BASE_DIR/$WVDIAL_DIR/default.conf ];
    then
        $ECHO "INFO: No default config file found. Run 'open3gs -r' or 'open3gs -i'."
    else
        $ECHO "INFO: Using default wvdial file. You can reconfigure with 'open3gs -r'."
    fi

    $ECHO "@ Activating modem..."
    chatOpts=$($CAT $BASE_DIR/$CONF_DIR/chat_default.conf)
    pppdOpts=$($CAT $BASE_DIR/$CONF_DIR/ppp_default.conf)

    chatOpts=$($ECHO $chatOpts | $SED 's/\"/\\\"/g')
    #echo "$PPPD $pppdOpts \"$CHAT -v $chatOpts\""
    eval "$PPPD $pppdOpts \"$CHAT -v $chatOpts\""
    sleep 5
    $KILLALL -9 pppd

    $ECHO "@ Dialing..."
    nohup $WVDIAL -C $BASE_DIR/$WVDIAL_DIR/default.conf > $LOG_DIR/open3gs.log 2>&1 &

    $ECHO "@ Connection active. Output can be found in $LOG_DIR/open3gs.log"
}

disconnect()
{
    $ECHO "@ Stopping active connection..."
    $KILLALL -9 wvdial
    $KILLALL -9 pppd
}

reconnect()
{
    disconnect
    sleep 1
    reconnect
}

connStatus()
{

}

usage()
{
    echo
    echo ">> Usage: open3gs [option|optional]"
    echo
    echo "status, -s                    Status of the connection"
    echo "connect, -c                   Connect to the auto-detected carrier"
    echo "disconnect, -d                Close active connection"
    echo "reconnect, -n                 Finishes the actual connection/process and try to connect again."
    echo "reconfigure, -r               Detect the modem and APN and build the default configuration file."
    echo "aways, -a                     Always detect modem, APN, configure the modem and dial."
    echo "help, -h                      Display this screen"
    echo
}
