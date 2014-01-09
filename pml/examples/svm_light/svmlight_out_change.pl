#!/usr/bin/perl
#Change the output of the predicted file
#The label with the value smaller than 0 would be translated to the first label
#The label with the value larger than 0 would be translated to the second label
#!/usr/bin/perl
#Change the .arff data into .libsvm format
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
my ($in , $org_data , $out) = @ARGV;
my $att_num = 0; my @atts; my $last_att;
my %hash_label; my $switch = 0;
open FID,$org_data;
while (my $line = <FID>){
	if ($line =~ /^\@attribute/i){
		push @atts,$att_num;
		$att_num++; 
		if ($line =~ /^\@attribute\s+\S+\s+\{([^\}]+)\}/){
			$last_att = $1;
			my $n = -1;
			map{				
				$hash_label{$n} = $_;
				$n++;
				$n++ if $n == 0;
			}split /,/,$last_att;
		}
		else{
			$last_att = '0';
		}
	}
	elsif($line =~ /^\@data/){
		last;
	}
}
close FID;

open FID,$in;
open FID_out,">$out";
while(my $line = <FID>){
	next if $line =~ /^\s+$/;
	$line =~ s/\s+$//;
	if ($last_att){
		print FID_out $hash_label{-1} if $line < 0;
		print FID_out $hash_label{1} if $line >= 0;
	}
	else{
		print FID_out $line;
	}
	print FID_out "\n";
}
close FID;
close FID_out;
