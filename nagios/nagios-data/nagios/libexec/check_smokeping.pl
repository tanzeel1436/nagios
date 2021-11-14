#!/usr/bin/perl
#
# check_smokeping.pl - nagios plugin 
#
# Copyright (C) 2006 Larry Low
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to:  llow0@yahoo.com
#
# Version 0.2 - was not checking if file exists (or accesible) - fixed
#
use strict;
use warnings;
use lib "/usr/local/nagios/libexec"  ;
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	print ("ERROR: Plugin took too long to complete (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

$PROGNAME = "check_smokeping.pl";
sub print_help ();
sub print_usage ();

my ($opt_h,$opt_V,$opt_v);
my ($rrd_file);
my ($loss_warning,$loss_critical,$latency_warning,$latency_critical,$jitter_warning,$jitter_critical);

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
	"V"   => \$opt_V,	    "version"       => \$opt_V,
	"h"   => \$opt_h,	    "help"          => \$opt_h,
	"v"   => \$opt_v,	    "verbose"       => \$opt_v,
	"r=s" => \$rrd_file,	    "rrd=s"         => \$rrd_file,
	"l=i" => \$loss_warning,    "losswarn=i"    => \$loss_warning,
	"L=i" => \$loss_critical,   "losscrit=i"    => \$loss_critical,
	"t=f" => \$latency_warning, "latencywarn=f" => \$latency_warning,
	"T=f" => \$latency_warning, "latencycrit=f" => \$latency_warning,
	"j=f" => \$jitter_warning,  "jitterwarn=f"  => \$jitter_warning,
	"J=f" => \$jitter_critical, "jittercrit=f"  => \$jitter_critical
);

# -h & --help print help
if ($opt_h) { print_help(); exit $ERRORS{'OK'}; }
# -V & --version print version
if ($opt_V) { print_revision($PROGNAME,'$Revision: 0.2 $ '); exit $ERRORS{'OK'}; }
# no rrd line specified print help
if (!defined($rrd_file)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }

use RRDs;
my $state = 'UNKNOWN';
my $output = '';
# Begin plugin check code
{
	if (!(-e $rrd_file)) {
		$state = 'UNKNOWN';
		print ("$state: RRD error: RRD file $rrd_file does not exist.\n");
		exit $ERRORS{$state};
	}
	my $lastupdatetime = RRDs::last($rrd_file); # will be padded by 60 seconds below
	my $lasttimestamp = time;
	my ($start,$step,$ds_names,$data) = RRDs::fetch($rrd_file,"AVERAGE","-s",$lastupdatetime - 120,"-e","now");
	if (($lasttimestamp - $lastupdatetime) > ($step + 60)) {
		$state = 'UNKNOWN';
		print ("$state: RRD error: RRD file $rrd_file has not been updated in last ".($step + 120)." seconds.\n");
		exit $ERRORS{$state};
	}

	my $previous_ds;

	my $lastvalpos = @$data - 2;
	while ($lastvalpos >= 0) {
		if (defined(@$data[$lastvalpos]->[1])) {
			last;
		}
		if ($lastvalpos == 0) {
			$state = 'UNKNOWN';
			print ("$state: RRD file $rrd_file has no data in last ".($lasttimestamp - $lastupdatetime)." seconds.\n");
			exit $ERRORS{$state};
		}
		$lastvalpos--;
	}

	my $i = 0;
	my ($loss,$median,$ping);
	my $pingmax = 0;
	my $pingmin = 10000000;
	my $jitter = 0;
	my $pingcount = 0;
	foreach my $curr_ds (@$ds_names) {
		my $lastval = @$data[$lastvalpos]->[$i];

		if ($curr_ds eq "loss") {
			$loss = $lastval;
		} elsif ($curr_ds eq "median") {
			$median = $lastval;
		} elsif ($curr_ds =~ /^ping/) {
			$pingcount++;
			if (defined($lastval)) {
				if ($lastval > $pingmax) {
					$pingmax = $lastval;
				}
				if ($lastval < $pingmin) {
					$pingmin = $lastval;
				}
			}
		}
		$i++;
	}
	$loss = (sprintf("%.0f",$loss) / $pingcount) * 100;

	$state = 'OK';
	if (defined($loss_critical) && ($loss >= $loss_critical)) {
		$state = 'CRITICAL';
		$output .= sprintf("Loss !%.0f%%!",$loss);
	} elsif (defined($loss_warning) && ($loss >= $loss_warning)) {
		if ($state eq 'OK') {$state = 'WARNING'};
		$output .= sprintf("Loss *%.0f%%*",$loss);
	} else {
		$output .= sprintf("Loss %.0f%%",$loss);
	}

	# if loss not 100% then do some ping alarm checks
	if ($loss != 100) {
		$jitter = $pingmax - $pingmin;

		$median = $median * 1000;
		$pingmax = $pingmax * 1000;
		$pingmin = $pingmin * 1000;
		$jitter = $jitter * 1000;

		$output .= sprintf(" Median %.3f ms",$median);
		$output .= sprintf(" Min %.3f ms",$pingmin);

		if (defined($latency_critical) && ($pingmax >= $latency_critical)) {
			$state = 'CRITICAL';
			$output .= sprintf(" Max !%.3f! ms",$pingmax);
		} elsif (defined($latency_warning) && ($pingmax >= $latency_warning)) {
			if ($state eq 'OK') {$state = 'WARNING'};
			$output .= sprintf(" Max *%.3f* ms",$pingmax);
		} else {
			$output .= sprintf(" Max %.3f ms",$pingmax);
		}

		if (defined($jitter_critical) && ($jitter >= $jitter_critical)) {
			$state = 'CRITICAL';
			$output .= sprintf(" Jitter !%.3f! ms",$jitter);
		} elsif (defined($jitter_warning) && ($jitter >= $jitter_warning)) {
			if ($state eq 'OK') {$state = 'WARNING'};
			$output .= sprintf(" Jitter *%.3f* ms",$jitter);
		} else {
			$output .= sprintf(" Jitter %.3f ms",$jitter);
		}
	}
}
print "SMOKEPING $state - $output\n";
exit $ERRORS{$state};

sub print_help() {
	print_revision($PROGNAME,'$Revision: 0.2 $ ');
	print "Copyright (c) 2006 Larry Low\n";
	print "This program is licensed under the terms of the\n";
	print "GNU General Public License\n(check source code for details)\n";
	print "\n";
	printf "Check smokeping rrd file.\n";
	print "\n";
	print_usage();
	print "\n";
	print " -r (--rrd)         Smokeping RRD file to check (required)\n";
	print " -l (--losswarn)    Percent of loss to return warning\n";
	print " -L (--losscrit)    Percent of loss to return critical\n";
	print " -t (--latencywarn) Latency to return warning\n";
	print " -T (--latencycrit) Latency to return critical\n";
	print " -j (--jitterwarn)  Jitter to return warning\n";
	print " -J (--jittercrit)  Jitter to return critical\n";
	print " -V (--version)     Plugin version\n";
	print " -h (--help)        usage help\n";
	print "\n";
	support();
}

sub print_usage() {
	print "Usage: \n";
	print "  $PROGNAME -r <rrd_file>\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

