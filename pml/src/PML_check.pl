#!/usr/bin/perl
#This script is to check the statues of modules of PML.
#
#PML is free software; you can redistribute it and/or modify it 
#under the terms of the GNU General Public License as published 
#by the Free Software Foundation, either version 3 of the License, 
#or (at your option) any later version.
#
#PML is distributed in the hope that it will be useful, 
#but WITHOUT ANY WARRANTY; without even the implied warranty of 
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
#See the GNU General Public License for more details.
#
#You should have received a copy of the GNU Lesser General Public License 
#along with PML. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
my @modules = ('strict' , 'warnings' , 'File::Copy' , 'Archive::Tar' , 'Cwd' , 
	'Scalar::Util' , 'threads' , 'threads::shared' , 'Exporter');
my @miss;
print "Check the modules...\n";
for (@modules){
	my $name = $_;
	$name =~ s/::/\//g;
	$name .= '.pm';
	print "Module $_ ... ";
	if(grep{-f $_ . '/' . $name}@INC){
		print "OK\n";
	}
	else{
		print "miss\n";
		push @miss,$_;
	}
}
print "\n";
if (!@miss){
	print "All the modules for PML are installed, you can use PML normally.\n"
}
else{
	print "Module";
	print 's' if scalar @miss > 1;
	print ': ' . join(' ',@miss) . ' ';
	print 'are ' if scalar @miss > 1;
	print 'is ' if scalar @miss == 1;
	print 'needed to be installed.'
}




