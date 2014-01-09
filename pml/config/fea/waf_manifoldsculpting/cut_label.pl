#!/usr/bin/perl
#Cut the lable attribute of data.arff

use strict;
use warnings;

open(FID_org,'data.arff');
open(FID_out,'>data_no_label.arff');

my $att = '';
my $switch = 0;
while (my $line = <FID_org>){
	if ($line =~ /^\@ATTRIBUTE/i){
		print FID_out $att;
		$att = $line;
	}
	elsif ($line =~ /^\@DATA/i){
		$switch = 1;
		print FID_out $line;
	}
	elsif ($switch){
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		my @elements = split /,/,$line;
		pop @elements;
		print FID_out join(',',@elements);
		print FID_out "\n";
	}
	elsif ($line =~ /^\%/i and $switch){
		print FID_out $line;
		$switch = 0;
	}
	else{
		print FID_out $line;
	}
}
