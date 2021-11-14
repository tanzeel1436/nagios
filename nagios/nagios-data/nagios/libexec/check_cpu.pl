#!/usr/bin/perl
#
use strict;

use Getopt::Compact;

use vars qw( $VERSION $PARAM_H $opts @AVGS );

#
# Global variable definitions
#

$VERSION = "1.0";
$PARAM_H = '/usr/src/linux/include/asm/param.h';

#
# Project modules
#
use FindBin qw($Bin);
use lib "$Bin";

use misc;

sub actionsOnArgs() {
    # Make sure that the default (used CPU%) is active if the user has not made a choice...
    $opts->{'idle'} = 0 if ( ! defined $opts->{'idle'} );

    # Restrict verbosity to three levels.
    $opts->{'verbose'} = 3 if ( defined $opts->{'verbose'} && $opts->{'verbose'} > 3 );

    # Find out the number of CPUs in the machine unless sane value is provided on command line ...
    if ( $opts->{'cpus'} > 0 ) {
        log_timed_msg( 'DEBUG', "Number of CPUs is overridden on commandline.\n", 3 );
    } elsif ( -f '/proc/stat' && -r _ ) { # Do we have a /proc/stat and can we read it.
        if ( open( STAT, '</proc/stat' ) ) {
            my @lines = grep( /^cpu\d+\s+/, <STAT> );
            close( STAT );

            $opts->{'cpus'} = scalar( @lines );
        } else {
            log_timed_msg( 'FATAL', "Failed to open /proc/stat: $!\n" );

            exit 3;
        }
    } else {
        log_timed_msg( 'FATAL', "Unable to find or read /proc/stat.\n" );

        exit 3;
    }

    log_timed_msg( 'DEBUG', "Found " . $opts->{'cpus'} . " CPU(s).\n", 3 );

    # Make sure we have sane jiffies set.
    if ( ! $opts->{'jiffies'} || $opts->{'jiffies'} <= 0 ) {
        # Set the default value.
        $opts->{'jiffies'} = 100;

        # Can we figure out the correct value by checking the param.h file ?
        if ( -f $PARAM_H && -r _ ) {
            # Yes ... maybe ...
            if ( open( PARAM, '<' . $PARAM_H ) ) {
                # ... maybe ...
                my @lines = grep( /^\s*#\s*define\s+USER_HZ\s+/, <PARAM> );
                close( PARAM );

                if ( $lines[0] =~ /\s+USER_HZ\s+(\d+)/ ) {
                    $opts->{'jiffies'} = $1;

                    log_timed_msg( 'DEBUG', "Found the correct number of jiffies per second: " . $opts->{'jiffies'} . "\n", 3 );
                } else {
                    # ... No! ;( ...
                    log_timed_msg( 'DEBUG', "Unable to figure out correct jiffies for this platform.\n", 3 );
                }
            } else {
                # ... No! ;( ...
                log_timed_msg( 'DEBUG', "Unable to figure out correct jiffies for this platform.\n", 3 );
            }
        } else {
            # No! ;( ...
            log_timed_msg( 'DEBUG', "Unable to figure out correct jiffies for this platform.\n", 3 );
        }

        log_timed_msg( 'DEBUG', "Using jiffies: " . $opts->{'jiffies'} . "\n", 3 );
    }

    # make sure required trigger levels are provided and that they are in the right format.
    foreach my $o ( qw(warning critical) ) {
        if ( ! defined $opts->{$o} ) {
            log_timed_msg( 'FATAL', "Required option --$o is missing.\n" );

            exit 3;
        } elsif ( $opts->{$o} !~ /^(\d+|\d+\.\d+)$/ ) {
            log_timed_msg( 'FATAL', "Illegal value for option --$o: " . $opts->{$o} . "\n" );

            exit 3;
        }
    }
}

# Calculate the time percentage that the argument represents taking into consideration the number of
# jiffies per second and the number of CPUs in the machine.
sub jiffy( $ ) {
    my $jiffies = shift;

    return $jiffies / $opts->{'jiffies'} * 100 / $opts->{'cpus'};
}

# Get all the values and perform the calculations ...
sub getCPUData() {
    my @lines = ();
    my @data = ();

    # If we can't read /proc/stat it is no use even doing any work
    if ( -r '/proc/stat' ) {
        # Get all the values ... we need 6 samples ...
        for ( my $i=0; $i < 6; $i++ ) {
            if ( open( STAT, '</proc/stat' ) ) {
                @lines = grep( /^cpu\s+/, <STAT> );
        
                close( STAT );

                # Make sure our /proc/stat follows the supported format ... or fail.
                if ( $lines[0] =~ /cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/ ) {
                    push( @data, [ $1, $2, $3, $4, $5 ] );
                } else {
                    log_timed_msg( 'FATAL', "Unsupported /proc/stat format.\n" );

                    exit 3;
                }
            }

            # Sleep 1 second ...
            select( undef, undef, undef, 1 );
        }

        # Sum up all the differences ...
        for ( my $i=0; $i < 5; $i++ ) {
            log_timed_msg( 'DEBUG',
                sprintf( "Sample #%d - Idle:%.2f%%  Used:%.2f%% (User:%.2f%%  Nice:%.2f%%  Sys:%.2f%%  Wait I/O:%.2f%%)\n",
                    $i + 1,
                    jiffy( $data[$i+1][3] - $data[$i][3] ),
                    ( jiffy( $data[$i+1][0] - $data[$i][0] ) + jiffy( $data[$i+1][2] - $data[$i][2] ) + jiffy( $data[$i+1][4] - $data[$i][4] ) ),
                    jiffy( $data[$i+1][0] - $data[$i][0] ),
                    jiffy( $data[$i+1][1] - $data[$i][1] ),
                    jiffy( $data[$i+1][2] - $data[$i][2] ),
                    jiffy( $data[$i+1][4] - $data[$i][4] ),
                ), 3
            );

            $AVGS[0] += jiffy( $data[$i+1][0] - $data[$i][0] );
            $AVGS[1] += jiffy( $data[$i+1][1] - $data[$i][1] );
            $AVGS[2] += jiffy( $data[$i+1][2] - $data[$i][2] );
            $AVGS[3] += jiffy( $data[$i+1][3] - $data[$i][3] );
            $AVGS[4] += jiffy( $data[$i+1][4] - $data[$i][4] );
        }

        # Calculate 5 second average values...
        $AVGS[0] /= 5;                                  # 5s User CPU %
        $AVGS[1] /= 5;                                  # 5s Nice user CPU %
        $AVGS[2] /= 5;                                  # 5s System CPU %
        $AVGS[3] /= 5;                                  # 5s Idle CPU %
        $AVGS[4] /= 5;                                  # 5s Wait I/O CPU %
        $AVGS[5] = $AVGS[0] + $AVGS[2] + $AVGS[4];      # 5s Average used CPU %

        log_timed_msg( 'DEBUG',
            sprintf( "5 sec avg - Idle:%.2f%%  Used:%.2f%% (User:%.2f%%  Nice:%.2f%%  Sys:%.2f%%  Wait I/O:%.2f%%)\n",
                $AVGS[3],
                $AVGS[5],
                $AVGS[0],
                $AVGS[1],
                $AVGS[2],
                $AVGS[4],
            ), 2
        );

    }
}

# Check the trigger levels and exit with the correct exit code ...
sub checkThresholds() {
    my $ret = 0;
    my $nagios_status = 'OK';

    if ( ( ! $opts->{'idle'} && ( $AVGS[5] >= $opts->{'warning'} && $AVGS[5] < $opts->{'critical'} ) ) ||
         (   $opts->{'idle'} && ( $AVGS[3] <= $opts->{'warning'} && $AVGS[3] > $opts->{'critical'} ) ) ) {
        # Warning...
        $ret = 1;
        $nagios_status = 'WARNING';
    } elsif ( ( ! $opts->{'idle'} && $AVGS[5] >= $opts->{'critical'} ) ||
              (   $opts->{'idle'} && $AVGS[3] <= $opts->{'critical'} ) ) {
        # Critical...
        $ret = 2;
        $nagios_status = 'CRITICAL';
    }

    printf( "%s - Idle:%.2f%%  Used:%.2f%% (User:%.2f%%  Nice:%.2f%%  Sys:%.2f%%  Wait I/O:%.2f%%)\n", $nagios_status, $AVGS[3], $AVGS[5], $AVGS[0], $AVGS[1], $AVGS[2], $AVGS[4]);
    
    exit $ret;
}

# If no arguments are supplied on the cmdline, show an informative help message.
if ( ! scalar( @ARGV ) ) { push( @ARGV, '--help' ); }

# Grab the cmdline options.
$opts = new Getopt::Compact(
    name => "CPU plugin for Nagios (on Linux 2.6 or compatible)", cmd => "check_cpu.pl", version => $VERSION,
    struct => [
        [ [ qw(i idle) ],     qq(             Controls if the plugin measures idle-% or used-%),    "!"  ],
        [ [ qw(v verbose) ],  qq(             Verbose information output (Incremental option 0-3)), "+"  ],
        [ [ qw(j jiffies) ],  qq(<integer>    Number of jiffies per second (See documentation)),    "=i" ],
        [ [ qw(cpus) ],       qq(<integer>    Number CPUs in the machine (See documentation)),      "=i" ],
        [ [ qw(w warning) ],  qq(<float>      Warning threshold (in percent)),                      "=s" ],
        [ [ qw(c critical) ], qq(<float>      Critical threshold (in percent)),                     "=s" ],
    ]
)->opts();

actionsOnArgs();

getCPUData();

checkThresholds();

__END__

=head1 NAME

check_cpu - A Linux CPU check plugin for Nagios

=head1 SYNOPSIS

check_cpu.pl [-vvv] [--(no-)idle] [--jiffies <integer>] --warning <float> --critical <float>

=head1 DESCRIPTION

This script should be used to correctly measure CPU utilization on a machine running Linux. The values are an average of the CPU utilization/idle time over a five second period. Both uni- and milti-processor machines are supported but all the calculations and triggers are performed on the total values for all CPUs, not per CPU. It can can be used to measure either idle time or used CPU time by use of an option. The warning and critical options are required and can be either floats or integers representing percentages at which the alerts will trigger. Be carefull to get the trigger levels right depending on if the script measures CPU idle time or used CPU time.

A few simple rules for the trigger levels are...

  Plugin measures total CPU idle time:
    --warning > --critical

  Plugin measures total CPU used time:
    --warning < --critical

The script uses the magical file /proc/stat to get information about the cpu usage. The numbers in /proc/stat are in jiffies per second and the number of jiffies depends on the define USER_HZ usually found in /usr/src/linux/include/asm/param.h. The script will try to find out the correct USER_HZ from this file and if it fails it will fallback to the default 100 jiffies per second which should be correct for most platforms (all Linux supported platforms but alpha and ia64). The number of jiffies per second can also be set on the command line using the -j (--jiffies) option.

-i, --idle     - Turns on measurement of total CPU idle time instead of the default total used CPU time. This option is negatiable, so --no-idle is a valid switch too resulting in the plugin using it's default behaviour which is to measure the total used CPU time.

-v, --verbose  - Turns on verbose DEBUG output. This is not usuable when the script is used as a plugin for Nagios, but can be handy when debugging it on the commandline. This switch is incremental which means that the option can be used between one to three times to increase the debug output verbosity. Both -vv and -vvv is thus legal options.

-j, --jiffies  - Set the number jiffies per second that the kernel uses. The script tries to get the correct jiffies from Linux kernel source includes but failing this it falls back to a default of 100. Don't use this option unless you know what you are doing.

--cpus         - Set the number of CPUs in the machine. Provided as a way to override the actual number of CPUs in the machine in case the user wants to perform triggering on values that aren't correctly modified depending on number of CPUs (100% idle time on 2 CPUs would yield 200% if this value was set to 1 on a 2 CPU machine). Don't use this option unless you know what you are doing, the number of CPUs are automatically checked by the script.

-w, --warning  - Sets the trigger level at which a WARNING alert will be issued by the script. This is a required option for this script to work.

-c, --critical - Sets the trigger level at which a CRITICAL alert will be issued by the script. This is a required option for this script to work.

=head1 LICENSE

This program is licensed under the GNU GPLv3. A copy of the license should be made available together with this program or it can be downloaded from http://www.gnu.org/licenses/gpl.html

=head1 TODO

Add performance data to the output string.

=head1 REQUIREMENTS

=over 2

=item *
Linux 2.x kernel (or OS with compatible /proc/stat)

=item *
Perl

=item *
Perl modules:

    Getopt::Compact
    misc.pm (Distributed with this plugin.)

=back

=head1 KNOWN BUGS

Because of the fact that the script opens a file, reads data from this file filtering out unwanted lines and lastly parses out the desired values for each of the six samples needed to get the five second average there is a risk of the values beeing a few jiffies off and thus resulting in slightly wrong values. The values should never be of by more then 1%. I don't see any way to correct this problem so I see it more as a feature, as we all know...a documented bug IS a feature. :)

=head1 AUTHOR

Fredrik Larsson <ekerim@gmail.com>

=cut
