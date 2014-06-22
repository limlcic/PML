#!/usr/bin/perl

#usage: select.pl in out <options>
#-select att1,att2,... 
#-remain val11,val21,num1,val21,val22,num2,... 
#-seed seed_num 
#-del 0/1

use strict;
use warnings;

my ($file_in , $file_out , %hash_p) = @ARGV;
open FID_in,$file_in;
my $count_att = 0;
my @atts;#record the position of the selected attributes
my %selected = map{$_,1}split /,/,$hash_p{'-select'};
my $switch = 0;
my $instance_num = 0;
my %hash_selected_atts;
while (my $line = <FID_in>){
	if ($line =~ /^\@attribute\s+(\S+)\s+/i){
		my $att_name = $1;
		my $att_name1 = $att_name;
		$att_name1 =~ s/^\'//;
		$att_name1 =~ s/\'$//;
		if (exists $selected{$att_name} or exists $selected{$att_name1}){
			push @atts,$count_att;
			$count_att++;
		}
	}
	elsif ($line =~ /^\@data/){
		$switch = 1;
	}
	elsif ($switch == 1){
		#read related elements into %hash_selected_atts
		next if $line =~ /^\s+$/;
		next if $line =~ /^%/;
		$instance_num++;
		$line =~ s/\n$//;
		my @ele = split /,/,$line;
		my $ele_name = join ' ',@ele[@atts];
		$hash_selected_atts{$ele_name} .= $instance_num . ' '; 
	}
}
close FID_in;

#generate a key-value transfer
my %hash_seq_line;
my %hash_remains;
for (keys %hash_selected_atts){
	my $name = $_;
	my $line = $hash_selected_atts{$_};
	$line =~ s/\s+$//;
	my @ele = split /\s+/,$line;
	map{$hash_seq_line{$_} = $name}@ele;
	
	$hash_remains{$name} = 1;
}

my @random_seq = randperm($instance_num , $hash_p{'-seed'});

#init the remians' counter

my @remains = split /,/,$hash_p{'-remain'};
for (my $i = 0; $i < $#remains; $i += 3){
	my $name = $remains[$i] . ' ' . $remains[$i + 1];
	$hash_remains{$name} = $remains[$i + 2];
}

#select the instances
for (@random_seq){
	my $seq_num = $_;
	my $class = $hash_seq_line{$seq_num};
	if ($hash_remains{$class}){
		$hash_remains{$class}--;
	}
	else{
		delete $hash_seq_line{$seq_num};
	}
}



#generate the output file
open FID_in,$file_in;
open FID_out,'>'.$file_out;
 $switch = 0; $instance_num = 0;
while (my $line = <FID_in>){
	if ($line =~ /^\@attribute\s+(\S+)\s+/i){
		my $att_name = $1;
		my $att_name1 = $att_name;
		$att_name1 =~ s/^\'//;
		$att_name1 =~ s/\'$//;
		if (exists $selected{$att_name} or exists $selected{$att_name1}){
			if (!$hash_p{'-del'}){
				print FID_out $line;
			}
		}
		else{
			print FID_out $line;
		}
	}
	elsif ($line =~ /^\@data/){
		$switch = 1;
		print FID_out $line;
	}
	elsif ($switch == 1){
		#read related elements into %hash_selected_atts
		next if $line =~ /^\s+$/;
		next if $line =~ /^%/;
		$instance_num++;
		$line =~ s/\n$//;
		my @ele = split /,/,$line;
		my $ele_name = join ' ',@ele[@atts];
		if ($hash_seq_line{$instance_num}){
			#print FID_out $line,"\n";
			if ($hash_p{'-del'}){
				for (0..$#atts){
					$ele[$_] = '%%%delete_it%%%'; 
				}
				@ele = grep{$_ ne '%%%delete_it%%%'; }@ele;
			}
			print FID_out join(',',@ele),"\n";
		}
	}
	else{
		print FID_out $line;
	}
}
close FID_in;
close FID_out;
















sub randperm{
	#Generate the pseudorandom sequence from 1 to $length.
	#Use Linear congruential generator
	my $rand_length = $_[0];
	my $seed = $_[1];
	my $L = 0;
	while (2 ** $L <= $rand_length){$L++;}
	my $T = 2 ** $L;
	my @rand_sequence;
	my $a = int($T / 64 * atan2(1,1)) * 8 + 5;
	my $c = int($T / 2 * 0.211324865) * 2 + 1;
	my $next_value = $seed;
	for my $i (1..$T){
		$next_value = ($a * $next_value + $c) % $T;
		if ($next_value < $rand_length){push(@rand_sequence,$next_value);}	
	}
	@rand_sequence = map{$_ + 1}@rand_sequence;
	return @rand_sequence; 
}
