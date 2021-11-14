#!/usr/bin/perl
#
# Modified by Tanzeel Iqbal <tanzeel_1436@hotmail.com>
# Last modified: 03-22-2014
#
# Usage: check_file -f <file> [-w | -c] [-a <hours>] [-n]
#
# Description:
#
# This plugin will determine whether a file exists or not.  You can have 
# return OK on either condition with the -n switch.  Also, a failed check
# can return WARNING or CRITICAL if the -w or -c is specified.  WARNING
# is the default.
#
# By adding the -a switch, the plugin also checks the age of the file in
# hours.  If the file is younger than the number of hours specified, the
# plugin will return OK, and WARN or CRIT otherwise.  With the -n option,
# the file is check to be *older* than the number of hours specified.
#
# The <file> argument should be a an absolute path to the file you are 
# interested in.
#
# Examples:
#
# Check to see if write.lock exists and return CRITICAL if not.
#   check_file -f /tmp/write.lock -c
#
# Check to see if write.lock exists and return CRITICAL if so.
#   check_file -f /tmp/write.lock -c -n
#
# Return WARNING if write.lock is older than 5 hours or does not exist. 
#   check_file -f /tmp/write.lock -a 5
#
# Return WARNING if write.lock is younger than 5 hours or does not exist. 
#   check_file -f /tmp/write.lock -a 5 -n
#


BEGIN {
    if ($0 =~ s/^(.*?)[\/\\]([^\/\\]+)$//) {
        $prog_dir = $1;
        $prog_name = $2;
    }
}

require 5.004;

use lib $main::prog_dir;
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
use Getopt::Long;

sub print_usage ();
sub print_version ();
sub print_help ();

    # Initialize strings
    $file = '';
    $plugin_revision = '$Revision: 1.1 $ ';

    # Grab options from command line
    GetOptions
    ("f|file=s"         => \$file,
     "a|age:s"          => \$age,
     "w|warning"        => \$warning,
     "c|critical"       => \$critical,
     "n|negate"         => \$negate,
     "v|version"        => \$version,
     "h|help"           => \$help);

    !($version) || print_version ();
    !($help) || print_help ();

    # Make sure log file is specified
    ($file) || usage("A file must be specified.\n");

    # Test for file existence
    if (-e $file) {
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
	my $agediff = (time() - $ctime) / 3600;
        if ($negate) {
            if ($age) {
		if ($agediff > $age) {
                    print "OK: File $file is $agediff hours old, threshold is >$age hours.\n";
	            exit $ERRORS{'OK'};
	        } else {
	            if ($critical) {
                        print "CRITICAL: File $file is $agediff hours old, threshold is >$age hours.\n";
		        exit $ERRORS{'CRITICAL'};
	            } else {
                        print "WARNING: File $file is $agediff hours old, threhsold is >$age hours.\n";
		        exit $ERRORS{'WARNING'};
		    }
		}
	    } else {
                if ($critical) {
                    print "CRITICAL: File $file exists.";
                    exit $ERRORS{'CRITICAL'};
	        } else {
                    print "WARNING: File $file exists.";
		    exit $ERRORS{'WARNING'};
	        }
	    }
	} else {
            if ($age) {
		if ($agediff <= $age) {
                    print "OK: File $file is $agediff hours old, threshold is <=$age hours.\n";
	            exit $ERRORS{'OK'};
	        } else {
	            if ($critical) {
                        print "CRITICAL: File $file is $agediff hours old, threshold is <=$age hours.\n";
		        exit $ERRORS{'CRITICAL'};
	            } else {
                        print "WARNING: File $file is $agediff hours old, threhsold is <=$age hours.\n";
		        exit $ERRORS{'WARNING'};
		    }
		}
	    } else {
                print "OK: File $file exists.";
	        exit $ERRORS{'OK'};
            }
        }
    # File does not exist so branch down here.
    } else {
        if ($negate && !$age) {
            print "OK: File $file does not exist.";
	    exit $ERRORS{'OK'};
	} else {
	    if ($critical) {
                ($age && print "CRITICAL: File $file does not exist but age check requested.")
		|| print "CRITICAL: File $file does not exist.";
		exit $ERRORS{'CRITICAL'};
	    } else {
                ($age && print "WARNING: File $file does not exist but age check requested.")
		|| print "WARNING: File $file does not exist.";
		exit $ERRORS{'WARNING'};
	    }
        }
    }
		

#
# Subroutines
#

sub print_usage () {
    print "Usage: $prog_name -f <file> [-w | -c] [-a <hours>] [-n]\n";
    print "Usage: $prog_name [ -v | --version ]\n";
    print "Usage: $prog_name [ -h | --help ]\n";
}

sub print_version () {
    print_revision($prog_name, $plugin_revision);
    exit $ERRORS{'OK'};
}

sub print_help () {
    print_revision($prog_name, $plugin_revision);
    print "\n";
    print "Check for file existence.\n";
    print "\n";
    print_usage();
    print "\n";
    print "-f, --file=<file>\n";
    print "    The file to be checked\n";
    print "-a, --age=<hours>\n";
    print "    Make sure the file is younger (ctime) than the number of hours listed\n";
    print "-w, --warning\n";
    print "    Return warning if file does not exist\n";
    print "-c, --critical\n";
    print "    Return critical if file does not exist\n";
    print "-n, --negate\n";
    print "    Negate the return of the check i.e. check for file nonexistence or\n";
    print "    check to see if file is older rather than newer if -a is used\n";
    print "\n";
    support();
    exit $ERRORS{'OK'};
}

