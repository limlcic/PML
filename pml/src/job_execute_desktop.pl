#!/usr/bin/perl
#This file is part of PML
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

use File::Copy;

my $wu = $ARGV[0];
my $name = $ARGV[1];
my $prog_dir = $ARGV[2];

my $bkdir = "../../..";
chdir "$prog_dir/wus/wu$wu";
#system "perl ./pml_run.pl";
do "pml_run.pl";

chdir $bkdir;
