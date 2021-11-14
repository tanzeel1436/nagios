#!/usr/bin/perl
# Last modified: 03-22-2014
# Modified by Tanzeel Iqbal <tanzeel_1436@hotmail.com>
#
# Usage: check_fileContents_lock.pl directory_path
# e.g. /usr/local/nagios/libexec/check_fileContents_lock.pl /var/log/sync
# Description:
#
# This plugin will determine whether a specific string exists in all .status files of specified directory or not 
# and then also check the lock file in mentioned directory with is hard coded in botton of script which is "/tmp/.rsync.lock".  You can have
# return OK if lock file not there and keyword "SUCCESS :" found in files of specified directory.  Also, a failed check
# can return CRITICAL either text found in any file of mentioned directory or lock file found in /tmp directory
# is the default.
#

use strict;
use warnings;

opendir my $DIR, $ARGV[0] or die "opendir .: $!\n";
my @files = grep /\.status$/i, readdir $DIR;
closedir $DIR;
# print "Got ", scalar @files, " files\n";


my $found = 0;
my $error = 0;
my %errFile = ();
my %seen = ();
my $op = "";
my $state = "";
my $exitCode = 0;

foreach my $file (@files) {
   my $fileName = $ARGV[0] . "/". $file; 
   $found = 0;
    
    open my $FILE, '<', $fileName or die "$file: $!\n";
    while (<$FILE>) {
        if (/^SUCCESS :\s*(.*)\r?$/i) {
            $seen{$1} = 1;
           $found = 1;
        }
    }
    close $FILE;

   if($found != 1)
   {
      $error = 1;
      $errFile{$file} = 1;
   }

}

if($error == 0)
{
 foreach my $addr (sort keys %seen) {
	$state = 'OK';
   #print "$state: $addr";
	$op = $addr;	
 }
}
else
{
	$state = 'CRITICAL';
  #print "$state: Something Wrong with .STATUS file: ";
   $op = "Something Wrong with .STATUS file: ";   
   $exitCode = 1;

 foreach my $wfile (sort keys %errFile) {
    #print "$wfile, ";
    $op .= "$wfile, ";
 }

}
if (-e "/tmp/.rsync.lock"){
	$state = ' CRITICAL';
        print "$state : $op";
        print "  Rsync Lock File Exists \n";
        exit 1;
}

 print "$state : $op";
print " and RSYNC lock file not exist!\n";
exit $exitCode;

