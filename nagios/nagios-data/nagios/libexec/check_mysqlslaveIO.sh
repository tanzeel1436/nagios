#! /bin/sh

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
mysqlpath='/usr/local/mysql/bin'
crit="No"
null="NULL"
ok="Yes"
usage1="Usage: $0 -u user -p password -H localhost"

exitstatus=$STATE_WARNING #default
while test -n "$1"; do
    case "$1" in
        -u)
            user=$2
            shift
            ;;
        -p)
            pass=$2
            shift
            ;;
        -h)
            echo $usage1;
            echo
            exit $STATE_UNKNOWN
            ;;
        -H)
            host=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo $usage1;
            echo
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done

answer=`$mysqlpath/mysql -S/var/lib/mysql/mysql.sock -u $user -p$pass -e 'show slave status\G' | /bin/grep Slave_IO_Running | /bin/cut -f2 -d:`

# if null, critical
if [ $answer = $null ]; then
echo CRITICAL - $host -  Slave_IO_Running is answering Null
exit $STATE_CRITICAL;
fi

if [ $answer = $crit ]; then
echo CRITICAL - $host -  Slave_IO_Running $answer
exit $STATE_CRITICAL;
fi

if [ $answer = $ok ]; then
echo OK - $host -  Slave_IO_Running $answer
exit $STATE_OK;
fi
