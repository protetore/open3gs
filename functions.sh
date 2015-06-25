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
            $ECHO "Dependency no found: $dep"
            retval=1
        fi
    done

    return $retval
}

checkModem()
{
    # Find where modem is
    $MODEM=/dev/ttyUSB0

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
        $ECHO "ERROR: APN could not be detected! Modem sent an empty reply."
        return 1;
    fi

    $confFile=$($GREP -l "COD=$apnCode" -r $BASE_DIR/$PROVIDERS_DIR/*.conf)

    if [ "$confFile" == "" ];
    then
        $ECHO "ERROR: No config file for APN: $apnCode"
        return 1;
    fi

    OP=$(basename $conFile)
    OP=$($ECHO ${OP%.conf})

    return 0;
}

readConf()
{
    retval=0

    if [ ! -f $BASE_DIR/$PROVIDERS_DIR/$OP.conf ];
    then
        $ECHO "Config file $BASE_DIR/$PROVIDERS_DIR/$OP.conf not found!"
        exit 1;
    fi

    #IFS="\n"
    #confs=( $(cat "$BASE_DIR/$PROVIDERS_DIR/$OP.conf") )
    #for conf in $confs
    #do
    #    echo $conf
    #done

    APN=$($GREP -m 1 APN "$BASE_DIR/$PROVIDERS_DIR/$OP.conf" | $SED '/^#.*$/d; s/APN=//')
    USR=$($GREP -m 1 USR "$BASE_DIR/$PROVIDERS_DIR/$OP.conf" | $SED '/^#.*$/d; s/USR=//')
    PWD=$($GREP -m 1 PWD "$BASE_DIR/$PROVIDERS_DIR/$OP.conf" | $SED '/^#.*$/d; s/PWD=//')
    ATD=$($GREP -m 1 ATD "$BASE_DIR/$PROVIDERS_DIR/$OP.conf" | $SED '/^#.*$/d; s/ATD=//')
    COD=$($GREP -m 1 COD "$BASE_DIR/$PROVIDERS_DIR/$OP.conf" | $SED '/^#.*$/d; s/COD=//')

    if [ $APN == "" ];
    then
        $ECHO "No APN (apn url) setting in $BASE_DIR/$PROVIDERS_DIR/$OP.conf!"
        retval=1
    fi

    if [ $USR == "" ];
    then
        $ECHO "No USR (user) setting in $BASE_DIR/$PROVIDERS_DIR/$OP.conf!"
        retval=1
    fi

    if [ $PWD == "" ];
    then
        $ECHO "No PWD (password) setting in $BASE_DIR/$PROVIDERS_DIR/$OP.conf!"
        retval=1
    fi

    if [ $ATD == "" ];
    then
        $ECHO "No ATD (phone to dial) setting in $BASE_DIR/$PROVIDERS_DIR/$OP.conf!"
        retval=1
    fi

    if [ $COD == "" ];
    then
        $ECHO "No COD (operator code) setting in $BASE_DIR/$PROVIDERS_DIR/$OP.conf!"
        retval=1
    fi

    return $retval;
}

setup()
{
    $ECHO "@ SETUP"
    $ECHO "@ Checking dependencies..."
    if [ ! checkDependencies ]; then exit 1 fi

    $ECHO "@ Checking scripts..."
    if [ "$0" == "/usr/bin/open3gs" ];
    then
            echo "Setup function must be called from the sh script not from the link in /usr/bin/"
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

        $CAT > /etc/logrotate.d/open3gs <<- END_CFG
            $LOG_DIR/*log {
                missingok
                notifempty
                size 30k
                monthly
                create 0600 root root
            }
            END_CFG
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

    $ECHO "@ Finished configuring Open3Gs."
    $ECHO
    usage
}

connect()
{
    if [ ! checkDependencies ]; then exit 1 fi

    if [ ! checkModem ];  then exit 1 fi

    if [ ! readConf ]; then exit 1 fi
}

disconnect()
{

}

reconnect()
{

}

status()
{

}

usage()
{
    echo
    echo ">> Usage: open3gs [option|optional]"
    echo
    echo "status                    Status of the connection"
    echo "connect                   Connect to the auto-detected carrier"
    echo "disconnect                Close active connection"
    echo "reconnect                 Finishes thw actual connection/process and try to connect again."
    echo "help                      Display this screen"
    echo
}
