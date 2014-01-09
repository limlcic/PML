#!/usr/bin/perl
#Add lable from data.arff to out_no_label.txt

use strict;
use warnings;

open(FID,'out_no_label.txt');
open(FID_org,'data.arff');
open(FID_out,'>out.txt');
my @lables; my $lable_lines; my $switch = 0;
while (my $line = <FID_org>){
	$lable_lines = $line if $line =~ /^\@ATTRIBUTE/i;
	if ($switch == 1){
		$line =~ s/\s+$//;
		push @lables,pop([split /,/,$line]);
	}
	$switch = 1 if $line =~ /^\@DATA/i;
	$switch = 0 if $line =~ /^\%/i;
	
}
if ($lable_lines =~ /^\@ATTRIBUTE\s+\S+\s+\{[^\}]+\}/){
	my $last_line = '';
	$switch = 0; my $line_count = 0;
	while (my $line = <FID>){
		print FID_out $lable_lines if $last_line =~ /^\@ATTRIBUTE/i && $line !~ /^\@ATTRIBUTE/i;
		$switch = 0 if $line =~ /^\%/i;
		print FID_out $line if $switch == 0;
		if ($switch == 1){
			
			$line =~ s/\s+$//;
			print FID_out $line . ',' . $lables[$line_count] . "\n";
			$line_count++;
		}
		$switch = 1 if $line =~ /^\@DATA/i;
		
		$last_line = $line;
	}
}

close FID_out;
close FID;
close FID_org;
