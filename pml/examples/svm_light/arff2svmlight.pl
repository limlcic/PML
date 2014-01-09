#!/usr/bin/perl
#Change the .arff data into .libsvm format
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
my ($in , $out) = @ARGV;
my $att_num = 0; my @atts; my $last_att;
my %hash_label; my $switch = 0;
open FID,$in;
open FID_out,'>'.$out;
while (my $line = <FID>){
	if ($line =~ /^\@attribute/i){
		push @atts,$att_num;
		$att_num++; 
		if ($line =~ /^\@attribute\s+\S+\s+\{([^\}]+)\}/){
			$last_att = $1;
			my $n = -1;
			map{				
				$hash_label{$_} = $n;
				$n++;
				$n++ if $n == 0;
			}split /,/,$last_att;
		}
		else{
			$last_att = '0';
		}
	}
	elsif($line =~ /^\@data/){
		$switch = 1;
	}
	elsif($switch == 1){
		next if $line =~ /^\s+$/;
		next if $line =~ /^\%/; 
		$line =~ s/\s+$//;
		my @ele = split /,/,$line;
		if ($last_att){
			print FID_out $hash_label{$ele[$#ele]};
		}
		else{
			print FID_out $ele[$#ele];
		}
		my $n = 0;
		map{
			$n++;
			if(looks_like_number($_) and $_ != 0){
				print FID_out ' ' . $n . ':' . $_;
			}			
		}@ele[0..$#ele-1];
		print FID_out "\n";
	}
}
close FID;
close FID_out;