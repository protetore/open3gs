[Required Packages]

pppd
wvdial
usb_modeswitch



[Commands]

1) Sample pppd:
	
/usr/sbin/pppd -d /dev/ttyUSB0 460800 noauth persist defaultroute noipdefault usepeerdns nodeflate refuse-pap user oi password oi connect "/usr/bin/chat -v TIMEOUT 300 ABORT \"BUSY\" ABORT \"NO DIALTONE\" ABORT \"NO CARRIER\" \"\" ATZ OK AT+cfun=1 OK AT+CGDCONT=1,\"IP\",\"gprs.oi.com.br\" -T ATDT*99# CONNECT \"\""

2) Connect with wvdial:

/usr/bin/wvdial -C /specta/3g/default.conf
