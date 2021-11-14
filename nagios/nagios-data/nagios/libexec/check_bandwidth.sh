#!/bin/bash

warn=$1
crit=$2

i=$(vnstat -tr)

rx_value=$(echo $i | grep -o "rx [[:digit:]]*\.[[:digit:]]* .bit/s" | awk '{ print $2 }' | cut -d. -f1)
tx_value=$(echo $i | grep -o "tx [[:digit:]]*\.[[:digit:]]* .bit/s" | awk '{ print $2 }' | cut -d. -f1)
rx_unit=$(echo $i | grep -o "rx [[:digit:]]*\.[[:digit:]]* .bit/s" | awk '{ print $3 }' | cut -d. -f1)
tx_unit=$(echo $i | grep -o "tx [[:digit:]]*\.[[:digit:]]* .bit/s" | awk '{ print $3 }' | cut -d. -f1)

#recalculate rx_value and tx_value, depending on the unit in rx_unit and tx_unit
#first for rx
if [ $rx_unit == "Mbit/s" ]
then rx_value_recal=`echo "$rx_value * 1024" | bc`
else rx_value_recal=`echo "$rx_value" | bc`
fi

#...then also for tx
if [ $tx_unit == "Mbit/s" ]
then tx_value_recal=`echo "$tx_value * 1024" | bc`
else tx_value_recal=$tx_value
fi

status="$rx_value_recal $tx_value_recal"

if [ $warn -lt $rx_value_recal -o $warn -lt $tx_value_recal ]
then
if [ $crit -lt $rx_value_recal -o $crit -lt $tx_value_recal ]
then
echo "CRITICAL: rx $rx_value_recal tx $tx_value_recal kbps. Limit of $crit exceeded"
exit 2
else
echo "WARNING: rx $rx_value_recal tx $tx_value_recal kbps. Limit of $warn exceeded"
exit 1
fi
else
echo "OK: rx $rx_value_recal tx $tx_value_recal kbps"
exit 0
fi
