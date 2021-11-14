#!/bin/sh
########################################################
#                                                      #
#         www.361way.com                               #
# Useage: check_traffic -i Interface -w warn -c cirt   #
# it's for pnp4nagios check the traffic                #
#                                                      #
######################################################## 


while getopts ":i:c:w:h" optname
  do
    case "$optname" in
      "i")
        INT=$OPTARG
        ;;
      "c")
        CIRT=$OPTARG
        ;;
      "w")
        WARN=$OPTARG
        ;;
      "h")
        echo "Useage: check_traffic -i Interface -w warn -c cirt"
        exit
        ;;
      "?")
        echo "Unknown option $OPTARG"
        exit
        ;;
      ":")
        echo "No argument value for option $OPTARG"
        exit
        ;;
      *)
      # Should not occur
        echo "Unknown error while processing options"
        exit
        ;;
    esac
  done

[ -z $INT ]&& echo "Please input Device!"&&exit
ifconfig $INT >/dev/null 2>&1
[ $? -ne 0 ] && echo "error: no device $INT" && exit || DEVICE=$INT


[ -z $WARN ] && WARN=1048576
[ -z $CIRT ] && CIRT=2097152

DIR=/App/nagios/tmp
FILE=$DIR/.network-$DEVICE.tmp
[ -e $DIR ] || mkdir -p $DIR
chown -R nagios.nagios $DIR
[ -e $FILE ] || >$FILE
if [ `cat /App/nagios/tmp/.network-$DEVICE.tmp | wc -c` -eq 0 ];then
        echo -en `date +%s`"\t" >$FILE
        echo -en `ifconfig $DEVICE | grep "RX bytes" | awk '{print $2}' | awk -F: '{print $NF}'`"\t" >>$FILE
        echo `ifconfig $DEVICE | grep "RX bytes" | awk '{print $6}' | awk -F: '{print $NF}'`>>$FILE
        echo "This is first run"
else
        New_Time=`date +%s`
        New_In=`ifconfig $DEVICE | grep "RX bytes" | awk '{print $2}' | awk -F: '{print $NF}'`
        New_Out=`ifconfig $DEVICE | grep "RX bytes" | awk '{print $6}' | awk -F: '{print $NF}'`
        Old_Time=`cat $FILE | awk '{print $1}'`
        Old_In=`cat $FILE | awk '{print $2}'`
        Old_Out=`cat $FILE | awk '{print $3}'`

        Diff_Time=`echo "$New_Time-$Old_Time"|bc`
        [ $Diff_Time -le 5 ] && echo "less 5s" && exit
        Diff_In=`echo "scale=0;($New_In-$Old_In)*8/$Diff_Time"|bc`
        Diff_Out=`echo "scale=0;($New_Out-$Old_Out)*8/$Diff_Time"|bc`
        [ $Diff_In -le 0 ] && Diff_In=`cat $FILE | awk '{print $4}'`
        [ $Diff_Out -le 0 ] && Diff_Out=`cat $FILE | awk '{print $5}'`
        echo "$New_Time $New_In $New_Out $Diff_In $Diff_Out" >$FILE

        if [ $Diff_In -gt $CIRT -o $Diff_In -eq $CIRT ];then
                echo -e "CIRT - $Diff_In|In=${Diff_In};${WARN};${CIRT};0;0;Out=${Diff_Out};${WARN};${CIRT};0;0"
                exit 2
        fi
        if [ $Diff_In -gt $WARN -o $Diff_In -eq $WARN ];then
                echo -e "WARN - $Diff_In|In=${Diff_In};${WARN};${CIRT};0;0;Out=${Diff_Out};${WARN};${CIRT};0;0"
                exit 1
        fi
        if [ $Diff_In -lt $WARN ];then
                echo -e "OK - $Diff_In|In=${Diff_In};${WARN};${CIRT};0;0;Out=${Diff_Out};${WARN};${CIRT};0;0"
                exit 0
        fi

fi
