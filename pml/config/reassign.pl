#!/usr/bin/perl
#
#Usage:
#reassign.pl filename(s)
#
#Reassign the sequence number of the methods in config files:
#If a config file contain:
#--------------------------
#1.weka arg1
#2.weka arg2
#2.waffles arg_new
#3.weka arg3
#7.3rd arg4
#--------------------------
#Use this script could change the file to:
#--------------------------
#1.weka arg1
#2.weka arg2
#3.waffles arg_new
#4.weka arg3
#5.3rd arg4
#--------------------------

use strict;
use warnings;
my $help_str = '
Usage:
reassign.pl filename(s)

Reassign the sequence number of the methods in config files:
If a config file contain:
--------------------------
1.weka arg1
2.weka arg2
2.waffles arg_new
3.weka arg3
7.3rd arg4
--------------------------
Use this script could change the file to:
--------------------------
1.weka arg1
2.weka arg2
3.waffles arg_new
4.weka arg3
5.3rd arg4
--------------------------
';

die $help_str if scalar @ARGV == 0;
map{
	die 'Can not find file' . $_ if !-f $_;
}@ARGV;
for(@ARGV){
	my $name = $_;
	open FID,$name;
	my @lines = <FID>;
	close FID;
	
	open FID_OUT,">$name";
	my $count = 0;
	for my $line (@lines){
		if ($line =~ /^(\d+)\./){
			$count++;
			$line =~ s/^\d+/$count/;
		}
		print FID_OUT $line;
	}
	close FID_OUT;
}
















