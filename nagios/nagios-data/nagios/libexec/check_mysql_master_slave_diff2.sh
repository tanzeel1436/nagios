#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use DBI;

my $options = { 'm' => 'localhost', 's' => 'localhost', 'r' => 3306, 'w' => 1000, 'c' => 5000 , 'u' => 'root', 'k' => '/var/lib/mysql2/mysql.sock', 'p' => 'password'};
GetOptions($options, "m=s", "s=s", "r=i", "w=i", "c=i", "u=s", "p=s", "k=s", "help");
my $max_binlog;

if (defined $options->{'help'}) {
        print <<INFO;
$0: compare mysql binary log position between servers

 check_replication.pl [ -m <masterhost> ] [ -s <slavehost> ]
 [ -r <port> ] [ -w <position> ] [ -c <position> ]
 [ -u <user> ] [ -p <pass> ] [ -k <socket> ]

  -m <masterhost>       - MySQL instance running as a master server (default: localhost)
  -s <slavehost>        - MySQL instance running as a slave server (default: localhost)
  -r <port>             - Port number MySQL is listening on (default: 3306)
  -w <position>         - Binlog position difference for warning state (default: 1000)
  -c <position>         - Binlog position difference for critical state (default: 5000)
  -u <user>             - Username with file and process privs to check status (default: root)
  -p <pass>             - Password for above user (default: password)
  -k <socket>           - Path to MySQL socket (default: /var/lib/mysql/mysql.sock)
  --help                - This help page

The user that is testing must be the same on all instances, eg:
  GRANT File, Process on *.* TO nagios\@192.168.0.% IDENTIFIED BY <pass>

Note: Any mysqldump tables (for backups) may lock large tables for a long
time. If you dump from your slave for this, then your master will gallop
away from your slave, and the difference will become large. The trick is to
set critical above this differnce and warning below.

(c) 2008 Modified for better Nagios and DRBD integration by Tanzeel Iqbal <tanzeel_1436\@hotmail.com>.
INFO
exit;
}

sub get_status {
        my $host = shift;
        my $role = shift;
        $ENV{MYSQL_UNIX_PORT} = $options->{'k'};
        require Carp;
        Carp::cluck "host" if !defined $host;
        Carp::cluck "port" if !defined $options->{'r'};
        Carp::cluck "dbuser" if !defined $options->{'u'};
        Carp::cluck "dbpass" if !defined $options->{'p'};
        my $dbh = DBI->connect("DBI:mysql:host=$host;port=$options->{'r'}", $options->{'u'}, $options->{'p'});
        if (not $dbh) {
                print "UNKNOWN: cannot connect to $host";
                exit 3;
        }

        if (lc ($role) eq 'master') {
                my $sql1 = "show variables like 'max_binlog_size'";
                my $sth1 = $dbh->prepare($sql1);
                my $res1 = $sth1->execute;
                my $ref1 = $sth1->fetchrow_hashref;
                $max_binlog = $ref1->{'Value'};
        }
        my $sql = sprintf "SHOW %s STATUS", $role;
        my $sth = $dbh->prepare($sql);
        my $res = $sth->execute;
        if (not $res) {
                die "No results";
        }
        my $ref = $sth->fetchrow_hashref;
        $sth->finish;
        $dbh->disconnect;
        return $ref;
}

sub compare_status {
        my ($a, $b) = @_;
        my ($master, $slave);
        if (defined($a->{'File'})) {
                $master = $a;
                $slave = $b;
        } elsif (defined($b->{'File'})) {
                $master = $b;
                $slave = $a;
        }
        $master->{'File_No'} = $1 if ($master->{'File'} =~ /(\d+)$/);
        $slave->{'File_No'} = $1 if ($slave->{'Relay_Master_Log_File'} =~ /(\d+)$/);
        my $diff = ($master->{'File_No'} - $slave->{'File_No'}) * $max_binlog;
        printf "Master: %d Slave: %d\n", $master->{'Position'}, $slave->{'Exec_Master_Log_Pos'};
        $diff += $master->{'Position'} - $slave->{'Exec_Master_Log_Pos'};
        my $state = sprintf "Master: %d/%d  Slave: %d/%d  Diff: %d/%d\n", $master->{'File_No'}, $master->{'Position'}, $slave->{'File_No'}, $slave->{'Exec_Master_Log_Pos'}, ($diff/$max_binlog), ($diff % $max_binlog);
        if ($diff >= $options->{'c'}) {
                print "CRITICAL: $state";
                exit 2;
        } elsif ($diff >= $options->{'w'}) {
                print "WARN: $state";
                exit 1;
        }
        print "OK: $state";
        exit 0;
}

compare_status(get_status($options->{'s'}, 'slave'), get_status($options->{'m'}, 'master'));
