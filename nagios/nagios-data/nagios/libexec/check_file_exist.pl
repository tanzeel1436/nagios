#!/usr/bin/perl -w
#
# check_file_exist.pl  -  Check Rsync lock File existance and modules availability
# Version: 1
#
# Modified by Tanzeel Iqbal <tanzeel_1436@hotmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE ON YOUR DISTRO.  See the
# GNU General Public License for more details.
#
#
if (-e "/tmp/.rsync.lock"){
	$state = 'CRITICAL';
	print "$state: Rsync Lock File Exists \n";	
	exit 2;
}
else{
	$state = 'OK';
   	print "$state: Rsync Lock File Does Not Exist \n";
	exit 0;
}

