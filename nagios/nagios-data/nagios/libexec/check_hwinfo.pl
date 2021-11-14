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

use strict;
use Getopt::Std;

my $command;
my $file;
my $handle;
my $section;
my $value;
my $tag;
my $flag;
my $dmiinfo;
my $hash_ref;

my @message;
my $message = "";
my $sep=":";

# Throw-away variables
my ($vendor,$product,$serial);
my ($n_cpu,$cpu_family,$cpu_speed,$cpu_fsb,$cpu_l2cache);

my $rcsid = '$Id$';
my $rcslog = '
  $Log$
';

####################################################
# Command-line Option Processing
my %optarg;
my $getopt_result;

$getopt_result = getopts('Vhf:t:', \%optarg) ;

if ( $getopt_result <= 0 || $optarg{'h'} == 1 ) {
	print STDERR "Extract and print hardware information for this system\n\n";
	print STDERR "Usage: $0 \[-h|-V] | \[-t sep]\n" ;
	print STDERR "\t-h\t... print this help message and exit\n" ;
	print STDERR "\t-V\t... print version and log, and exit\n" ;
	print STDERR "\t-t sep\t...use \"sep\" as column seperator\n" ;
	print STDERR "\t-t csv\t...create quoted comma-separated value output\n" ;
	print STDERR "\nExample:\n";
	print STDERR "\t$0 -t ','\n";
	exit 1;
}

if ( $optarg{'t'} ne undef ) {
	$sep = $optarg{'t'};
	if ( $sep eq "csv" ) {
		$sep = '","';
	}
}

$command = "dmidecode|cat|";

$ENV{PATH}="/sbin:/usr/sbin:/bin:/usr/bin";
if ( ! open(DMIDECODE,$command) ) {
	print "Could not execute $command\n";
	exit 2;
}

while ( <DMIDECODE> ) {
	if ( /^Handle.*(0x[0-9A-F]*)/i ) {
		$section = undef;
		$handle = $1;
	}
	if ( $section eq undef ) {
		if ( /DMI type/i ) {
			$section = <DMIDECODE>;
			chomp $section;
			$section =~ s/^\s*//;
			$section =~ s/\s*\sBlock$//i;
			$section =~ s/\s*\sName$//i;
			$section =~ s/\s*\sInformation$//i;
		}
		next;
	}
	# Create Hash of Hashes, where each value is available as
	#   $dmiinfo->$section->$tag
	#
	if ( /:/ ) {
		/(\S[^:]*):\s*(.*\S)/mi;
		$tag=$1;
		$value=$2;
		$tag =~ s/\s*\sName$//i;
		if( $value ne undef ) {
			$dmiinfo->{$section}{$handle}{$tag}=$value;
		}
	} elsif ( /\s(is|are)\s/mi ) {
		/(\S.*)\s(is|are)\s(.*)/i;
		$flag = $1;
		$value =$3;
		$dmiinfo->{$section}{$handle}{$tag.$flag}=$value;
	} elsif ( /\(/ ) {
		/(\S.*)\s\((.*)\)/i;
		$flag = $1;
		$value =$2;
		$dmiinfo->{$section}{$handle}{$tag.$flag}=$value;
	} elsif ( $dmiinfo->{$section}{$handle}{$tag} eq undef ) {
		/(\S.*)/;
		$flag = $1;
		$dmiinfo->{$section}{$handle}{$tag.$flag}="";
	} else {
		#print STDERR "Ignored line: $_";
	}
	#print "$section -- $tag == $value\n";
	#print "$section .. $tag .. $dmiinfo{$section}{$tag}\n";
	#print "$section ++ $tag ++ $flag ++ $dmiinfo{$section}{$tag.$flag}\n";
	$value = undef;
	$flag = undef;
}

close(DMIDECODE);

# Build Harware Information message:
#
# MB Vendor: Service Tag | 1/2/4:CPU_Type:CPU_Speed:CPU_FSB|Memory_Total ECC/Non-ECC | HDDs : HW RAID type (Perc2 etc) : Network 10/100/1000


# Motherboard Information
foreach $hash_ref ( values %{ $dmiinfo->{"System"} } ) {
	$vendor = $hash_ref->{"Manufacturer"}.$hash_ref->{"Vendor"};
	$product = $hash_ref->{"Product"};
	$serial = $hash_ref->{"Serial Number"};
}

foreach $hash_ref ( values %{ $dmiinfo->{"Base Board"} }, values %{ $dmiinfo->{"Board"} } ) {
	if ( $hash_ref->{"Manufacturer"} ne "" &&  $hash_ref->{"Manufacturer"} !~ /to be/i ) {
		$vendor = $hash_ref->{"Manufacturer"};
	}
	if( $product eq "" || $product =~ /to be/i ) {
		$product = $hash_ref->{"Product"};
	}
}

if( $serial eq "" || $serial =~ /Not Spec/i ) {
	foreach $hash_ref ( values %{ $dmiinfo->{"Chassis"} } ) {
		$serial = $hash_ref->{"Serial Number"};
	}

}
$message[0] = "$vendor$sep$product$sep$serial";
$n_cpu = 1;

# Processor Information
foreach $hash_ref ( values %{ $dmiinfo->{"Processor"} } ) {
	if ( $cpu_family eq undef ) {
		$cpu_family = $hash_ref->{"Family"}.$hash_ref->{"Processor Family"};
		if ( $cpu_family =~ /Unknown/mi || $hash_ref->{"Status"} =~ /Unpopulated/i ) {
			$cpu_family = undef;
		}
	} elsif( $cpu_family eq ($hash_ref->{"Family"}.$hash_ref->{"Processor Family"}) ) {
		$n_cpu++;
	}
	#if ( $hash_ref->{"Version"} ne "" && $hash_ref->{"Version"} !~ /not spec/i ) {
	#	$cpu_family = $hash_ref->{"Version"};
	#}
	$cpu_speed = $hash_ref->{"Current Speed"};
	$cpu_fsb   = $hash_ref->{"External Clock"};
}

foreach $hash_ref ( values %{ $dmiinfo->{"Cache"} } ) {
	if( $hash_ref->{"Configuration"} =~ /level 2/i && $hash_ref->{"Installed Size"} > 0 ) {
		$cpu_l2cache = $hash_ref->{"Installed Size"};
	}
}

$message[1] = "$n_cpu$sep$cpu_family$sep$cpu_speed$sep$cpu_l2cache$sep$cpu_fsb";

# Memory Information
my ($mem_total,$mem_size,$mem_max,$mem_ecc,@mem_devices);
foreach $hash_ref ( values %{ $dmiinfo->{"Physical Memory Array"} } ) {
	$mem_ecc = $hash_ref->{"Error Correction Type"};
	$mem_ecc =~ s/^None$/Non-ECC/;
	$mem_max= $hash_ref->{"Maximum Capacity"};
}

foreach $handle ( sort ( keys %{ $dmiinfo->{'Memory Device'} } ) ) {
	$mem_size = $dmiinfo->{"Memory Device"}{$handle}{"Size"};
	$mem_size =~ s/No Module Installed/0/;
	$mem_size =~ s/\s*([MG])B$/\1/;
	@mem_devices = (@mem_devices, $mem_size);
	if( $mem_size =~ /([0-9]*)\s*M/i ) {
		$mem_total += $1;
	} elsif ( $mem_size =~ /([0-9]*)\s*G/i) {
		$mem_total += $1 * 1024;
	}
}

$message[2] = "$mem_total M$sep$mem_ecc$sep". (join "/",@mem_devices);

#########################################################################
# Disk Information
#########################################################################
# 1/. For IDE, Scan /proc/ide/hd* and use /proc/ide/hd?/model  /proc/ide/hd?/media  
# 2/. For SCSI, Use /proc/scsi/sg/device_strs

$file = "< /proc/partitions";
if ( ! open(PARTITIONS,$file) ) {
	print "Could not open $file\n";
	exit 2;
}
my ($major,$minor,$size,$device);
my (@hdd_list,@raid_list,$raid_sw,$raid_hw,$raid);
my (%hdd_info,@hdd_info);
while ( <PARTITIONS> ) {
	($major,$minor,$size,$device) = split;
		$size = $size / 1024 / 1024;
	if( $device =~ /^[hs]d[a-z]$/i ) {
		@hdd_list = (@hdd_list, $device);
		$hdd_info{$device}{size}=$size;
		@hdd_info = (@hdd_info, "$device=".sprintf("%.1f",$size)." G");
	} elsif ( $device =~ /^md/ ) {
		@raid_list = (@raid_list, $device);
	}
}
close(PARTITIONS);

$message[3] = (join " / ", @hdd_info);

if( @raid_list > 0 ) {
	$raid_sw = "Linux SW RAID";
}


my @proc;
# Get HW Raid controller
open(PROC,"</proc/scsi/sg/device_strs")|| print STDERR "Cannot open /proc/scsi/sg/device_strs\n";
@proc = (<PROC>);
close(PROC);
($raid_hw) = (grep /raid/i,@proc);
chomp $raid_hw;
$raid_hw =~ s/\s*\t/,/g;
if ( $raid_hw ne "" && $raid_sw ne "" ) {
	$raid = "$raid_hw / $raid_sw";
} else {
	$raid = "$raid_hw$raid_sw";
}
if( $raid eq "" ) {
	$raid = "No Raid";
}

$message[3] .= "$sep$raid";

#########################################################################
# OS Release
#########################################################################
$file = "< /etc/redhat-release";
if ( ! open(OS_RELEASE,$file) ) {
	print "Could not open $file\n";
	exit 2;
}
$message = <OS_RELEASE>;
chomp $message;
if ( $message eq "" ) {
	$message = "Linux";
}
close(OS_RELEASE);

$message[4] = $message;

#########################################################################

if ( $optarg{'t'} ne undef ) {
	$message = (join $sep, @message );
	if ( $optarg{'t'} eq "csv" ) {
		$message = '"' . $message . '"' ;
	}
} else {
	$message = "[" . (join "][", @message ). "]";
}
$message =~ s/[<>]/ /g;
print $message . "\n";
exit 0;

