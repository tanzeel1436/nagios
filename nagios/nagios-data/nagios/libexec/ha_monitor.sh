#!/bin/bash
# Autor: Stanila Constantin Adrian
# Date: 20/03/2009
# Description: Check the number of active heartbeats
# http://www.randombugs.com

# Get program path
REVISION=1.3
PROGNAME=`/bin/basename $0`
PROGPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`

#nagios error codes
. $PROGPATH/utils.sh 

usage () {
    echo "\
Nagios plugin to heartbeat.

Usage:
  $PROGNAME -H host -C community 
  $PROGNAME [--help | -h]
  $PROGNAME [--version | -v]

Options:
  -H	Hostname for snmp disk query
  -C    Community for snmp disk query
  --help -l	Print this help information
  --version -v  Print version of plugin
"
}

help () {
    print_revision $PROGNAME $REVISION
    echo; usage; echo; support
}


# Verifies if check_snmp exists to ensure snmp utils are installed ... probably better we check for snmpwalk ... on the next version
if [ ! -x ${PROGPATH}/check_snmp ]
then
  echo "UNKNOWN - ${PROGPATH}/check_snmp not exists"
  exit $STATE_UNKNOWN
fi

while test -n "$1"
do
  case "$1" in
    --help | -h)
      help
      exit $STATE_OK;;
    --version | -v)
      print_revision $PROGNAME $REVISION
      exit $STATE_OK;;
    -H)
      shift
      HOST=$1;;
    -C)
      shift
      COMMUNITY=$1;;
    *)
      usage; exit $STATE_UNKNOWN;;
  esac
  shift
done

if [ "$HOST" == "" ]
then 
  echo "Parameter -H is necessary"
  exit $STATE_UNKNOWN
fi

if [ "$COMMUNITY" == "" ]
then
  echo "Parameter -C is necessary"
  exit $STATE_UNKNOWN
fi

# Exec snmp query
OID=.1.3.6.1.4.1.4682

declare -i I=0
#LINUX-HA-MIB::LHATotalNodeCount.0
NODES=$(snmpwalk -v 1 -On -c ${COMMUNITY} ${HOST} ${OID}.1.1.0 | cut -d"=" -f2 | cut -d":" -f2 | sed 's/ //g' | tr '\n' ' ')
#LINUX-HA-MIB::LHALiveNodeCount.0
LNODES=$(snmpwalk -v 1 -On -c ${COMMUNITY} ${HOST} ${OID}.1.2.0 | cut -d"=" -f2 | cut -d":" -f2 | sed 's/ //g' | tr '\n' ' ')

#Nodes == "" 
if [ $NODES =="" ]; then
	echo -e "HEARTBEAT Agent is not running !"
	exit $STATE_CRITICAL
fi

for index in `seq 1 ${NODES}`
do 
    #LINUX-HA-MIB::LHANodeStatus.x
    ACT=$(snmpwalk -v 1 -On -c ${COMMUNITY} ${HOST} ${OID}.2.1.4.${index} | cut -d"=" -f2 | cut -d":" -f2 | sed 's/ //g' | tr '\n' ' ')
    if [ $ACT != 3 ]; then
	let I=I+1
    fi
done

#if Number of failures == number of nodes we have a big problem
if [ $I == $NODES ]; then
	echo -e "HEARTBEAT is running out of nodes !"
	exit $STATE_CRITICAL
fi
#If  Number of nodes != of number of Live Nodes then we have a minor problem
if [ $NODES != $LNODES ]; then
	echo -e "HEARTBEAT lost some nodes !"
	exit $STATE_WARNING
fi
# if Number of failures != 0 the nwe have a minor problem (we already checked if  I==NODES)
if [ $I != 0 ]; then
	echo -e "HEARTBEAT lost some nodes !"
	exit $STATE_WARNING
fi

echo -e "All Heartbeats up and running !"
exit $STATE_OK

