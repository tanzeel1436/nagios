#!/usr/bin/perl -T
#############################################################################
#                                                                           #
# This script was initially developed by Anstat Pty Ltd for internal use    #
# and has kindly been made available to the Open Source community for       #
# redistribution and further development under the terms of the             #
# GNU General Public License: http://www.gnu.org/licenses/gpl.html          #
#                                                                           #
#############################################################################
#                                                                           #
# This script is supplied 'as-is', in the hope that it will be useful, but  #
# neither Anstat Pty Ltd nor the authors make any warranties or guarantees  #
# as to its correct operation, including its intended function.             #
#                                                                           #
# Or in other words:                                                        #
#       Test it yourself, and make sure it works for YOU.                   #
#                                                                           #
#############################################################################
# Author: George Hansper               e-mail:  Name.Surname@anstat.com.au  #
#############################################################################

$ENV{PATH}="/sbin:/usr/sbin:/bin:/usr/bin";

use strict vars;

my $rcsid = '$Id: check_dell_omreport.pl,v 1.5 2009/02/09 11:13:38 george Exp george $';
my $rcslog = '
  $Log: check_dell_omreport.pl,v $
  Revision 1.5  2009/02/09 11:13:38  george
  Battery in Non-Critical state now report WARNING instead of CRITICAL

  Revision 1.4  2008/11/13 03:47:52  george
  Added work-around for OpenMange 5.5 problem of newlines within SSV file
  Disk in Non-Critical state now report WARNING instead of CRITICAL

  Revision 1.3  2007/07/13 02:01:43  georgeh
  Added "charging" to battery states which result in Warning instead of critical

  Revision 1.2  2007/01/11 02:58:05  georgeh
  Added "rebuild" to disk states which result in Warning instead of critical

  Revision 1.1  2006/10/08 22:44:26  georgeh
  Initial revision

  Revision 1.1  2005/12/19 04:56:37  georgeh
  Initial revision

';

# Taint checks may fail due to the following...
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my $verbose=0;

if ( @ARGV > 0 ) {
	if( $ARGV[0] eq "-V" ) {
		print STDERR "$rcsid\n";
	} elsif ( $ARGV[0] eq "-v" ) {
		$verbose=1;
	} else {
		print STDERR "Nagios plugin for checking the status of a Dell RAID array using 'omreport'\n";
		print STDERR "Requires Dell Open Manage v4 to be installed.\n";
		print STDERR "\n";
		print STDERR "Usage:\n";
		print STDERR "\t$0 [-V|-v]\n";
		print STDERR "\t\t-V ... print version information\n";
		print STDERR "\t\t-v ... print verbose messages to STDERR\n";
		print STDERR "\n";
	}
}

my $cmd;

my $ctrlr_flds;
my $controller;
my $ctrlr_ndx;
my $cn;
my $vdisk_flds;
my $vdisk;
my $vdisk_ndx;
my $vn;
my $adisk_flds;
my $adisk;
my $adisk_ndx;
my $an;
my $batt_flds;
my $battery;
my $batt_ndx;
my $bn;
my $state;
my $progress;
my $crit=0;
my $warn=0;
my $ok=0;
my $message="";

sub printv($) {
	if ( $verbose ) {
		print STDERR join(' ',@_) . "\n";;
	}
}

sub runcmd( $ ) {
	my (@tag,@results,@values);
	my %fields;
	my $i;
	my $n_tags;
	my $n_values=0;
	my $n_value_set=0;
	my $overlapping_value;
	$ENV{BASH_ENV}=undef;
	open(CMD,"$cmd|")
		|| do { print "omreport: " . $! ."\n"; exit 2};
	while ( <CMD> ) {
		chomp;
		if( $_ =~ /^ID;/i ) {
			@tag=(split /;/, "$_" );
			for ($i=0 ; $i <  @tag ; $i++  ) {
				$fields{$tag[$i]} =$i;
			}
			$n_tags = @tag;
			# print $_ . "\n";
		} elsif ( @tag != 0 && $_ =~ /;/ ) {
			@values = (split /;/, "$_" );
			if ( $n_values == 0 ) {
				push @results, [ @values ];
				$n_values = @values;
			} elsif ( $n_values < $n_tags ) {
				$overlapping_value = shift @values;
				$results[$n_value_set][$n_values-1] .= $overlapping_value;
				push @{$results[$n_value_set]}, @values;
			}
			$n_values = @{$results[$n_value_set]};
			printv "\$n_value_set = $n_value_set  \$n_values = $n_values results = " . @results;
			if ( $n_values >= $n_tags ) {
				$n_values = 0;
				$n_value_set++;
			}
			#if ( @results > 0 ) {
			#	$results[$#results] .= $values[0];
			#	shift @values;
			#}
			# print $_ . "\n";
		}
		# print "\t$_\n" ;
	}
	close(CMD);
	#foreach $i ( sort( keys( %fields ) ) ) {
	#	printv("$i: $fields{$i}:" . join(" + ",@{$results[$fields{$i}]}) );
	#}
	return (\%fields,\@results);
}

# Identify the controllers...
$cmd= "omreport storage controller -fmt ssv";
($ctrlr_flds,$controller) = &runcmd($cmd);
printv "Controller: state=$ctrlr_flds->{Status}  $controller->[0][$ctrlr_flds->{ID}]   Status:  $controller->[0][$ctrlr_flds->{State}]\n";
# print ( join " , ", %ctrlr_flds ) , "\n";
if ( @{$controller} == 0 ) {
	$warn++;
	$message .= " No controllers found";
}
for ( $ctrlr_ndx=0; $ctrlr_ndx < @{$controller} ; $ctrlr_ndx++ ) {
# foreach $ctrlr ( @{$controller} ) {
	# print ( join " X ", @{$ctrlr} );
	# print "\n";
	$_ = $controller->[$ctrlr_ndx][ $ctrlr_flds->{ID} ];
	/([0-9]+)/m;
	$cn = $1;
	printv "Found Controller number $ctrlr_ndx: $cn";
	$state = "$controller->[$ctrlr_ndx][ $ctrlr_flds->{Status} ]/$controller->[$ctrlr_ndx][ $ctrlr_flds->{State} ]";
	$message .= " Controller$cn=$state [";
	if( $state =~ /^ok\/ready/i ) {
		$ok++;
	} elsif ( $state =~ /degrad/i ) {
		$warn++;
	} else {
		$crit++;
	}
	$cmd= "omreport storage battery controller=$cn -fmt ssv";
	($batt_flds,$battery) = &runcmd($cmd);
	for ( $batt_ndx=0; $batt_ndx < @{$battery} ; $batt_ndx++ ) {
		# print "bbb $battery->[$batt_ndx][0]\n";
		$_ = $battery->[$batt_ndx][ $batt_flds->{ID} ];
		if ( /No Batteries found/mi ) {
			last;
		}
		/([0-9:]+)/m;
		$bn = $1;
		$state = "$battery->[$batt_ndx][ $batt_flds->{Status} ]/$battery->[$batt_ndx][ $batt_flds->{State} ]";
		$message.=" Battery$cn=$state";
		if( $state =~ /^ok\/ready/i ) {
			$ok++;
		} elsif ( $state =~ /non-critical|degrad|charging|learning/i ) {
			$warn++;
		} else {
			$crit++;
			$message .= "**";
		}
		# print STDERR "battery=$bn Status=$battery->[$batt_ndx][$batt_flds->{Status}] State=$battery->[$batt_ndx][$batt_flds->{State}]\n";
	}
	# print STDERR "controller=$cn State=$controller->[$ctrlr_ndx][ $ctrlr_flds->{State} ]\n";
	$cmd= "omreport storage vdisk controller=$cn -fmt ssv";
	($vdisk_flds,$vdisk) = &runcmd($cmd);
	for ( $vdisk_ndx=0; $vdisk_ndx < @{$vdisk} ; $vdisk_ndx++ ) {
		$_ = $vdisk->[$vdisk_ndx][ $vdisk_flds->{ID} ];
		/([0-9]+)/m;
		$vn = $1;
		# print ( join " , ", %{$vdisk_flds} );
		# print "\n";
		$state = "$vdisk->[$vdisk_ndx][$vdisk_flds->{Status}]/$vdisk->[$vdisk_ndx][$vdisk_flds->{State}]";
		$progress = " $vdisk->[$vdisk_ndx][$vdisk_flds->{Progress}]";
		if ( $progress =~ /not appl/i ) {
			$progress = "";
		}
		$message .= " Vdisk$vn=$state$progress [";
		if( $state =~ /^ok\/ready/i ) {
			$ok++;
		} elsif ($state =~ /(degrad|regen)/i ) {
			$warn++;
		} else {
			$crit++;
		}
		# print STDERR "vdisk=$vn State=$vdisk->[$vdisk_ndx][$vdisk_flds->{State}]\n";

		$cmd= "omreport storage adisk vdisk=$vn controller=$cn -fmt ssv";
		($adisk_flds,$adisk) = &runcmd($cmd);
		for ( $adisk_ndx=0; $adisk_ndx < @{$adisk} ; $adisk_ndx++ ) {
			# print ( join " , ", %{$adisk_flds} );
			# print "\n";
			# print ( join " , ", @{$adisk->[$adisk_ndx]} );
			# print "\n";
			$_ = $adisk->[$adisk_ndx][ $adisk_flds->{ID} ];
			/([0-9:]+)/m;
			$an = $1;
			$state = "$adisk->[$adisk_ndx][$adisk_flds->{Status}]/$adisk->[$adisk_ndx][$adisk_flds->{State}]";
			$progress = " $adisk->[$adisk_ndx][$adisk_flds->{Progress}]";
			if ( $progress =~ /not appl/i ) {
				$progress = "";
			}
			$message .= " $an=$state$progress";
			if( $state =~ /^ok\/(ready|online)/i ) {
				$ok++;
			} elsif ($state =~ /(degrad|regen|rebuild|non-critical)/i ) {
				$warn++;
			} else {
				$crit++;
				$message .= "**";
			}
			# print STDERR "adisk=$an Status=$adisk->[$adisk_ndx][$adisk_flds->{Status}] State=$adisk->[$adisk_ndx][$adisk_flds->{State}]\n";
		}
		$message .= " ]";
	}
	$message .= " ] ";
}

if ( $crit != 0 ) {
	print "CRITICAL:$message\n";
	exit(2);
} elsif ( $warn != 0 ) {
	print "WARNING:$message\n";
	exit(1);
} else {
	print "OK:$message\n";
	exit(0);
}

