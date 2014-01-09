#!/usr/bin/perl
#
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
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Archive::Tar;
use File::Copy;

uncompressdir() if -e 'files.tgz';

open(FID,'step_prop');
my $line = <FID>;
$line =~ s/\s+$//;
close FID;

#@detail: nextstep outnumber outfold innerfold
my ($step,@details) = split / /,$line;

#figure out the system
#
my $system = $^O;
my $systype;
if ($system =~ /win/i){
	$system = 'win';
	$systype = $ENV{'processor_architecture'};
}
else{
	$systype = `uname -i`;
}

if ($systype =~ /64/){
	$systype = 'x86_64' ;
}else{
	$systype = 'x86';
}

dircopy($system , './') if -d $system;
dircopy($system . '_' . $systype , './') if -d $system . '_' . $systype;

#read script and get the out.txt
open(FID,'script');
while (my $line = <FID>){
	if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
	system $line if $line !~ m/^\n/ && $line !~ /^\#/;
}
close FID;

if (!-f 'out.txt'){
	#if out.txt is not exist, return
	if ($step eq 'tt'){
		open(FID,'>out.txt.pre');
		close FID;
	}else{
		open(FID,'>out.txt.arff');
		close FID;
	}
	return;
}
if (-s 'out.txt' == 0){
	#if the size of file out.txt is 0, return
	if ($step eq 'tt'){
		rename('out.txt','out.txt.pre');
	}else{
		rename('out.txt','out.txt.arff');
	}
	return;
}
#clu/fea => out.txt.arff
#tt => out.txt.pre
if ($step eq 'tt'){
	analysis_data('test.arff','test.info');
	#output the modeling result after check the instance number between the prediction and org data
	my @labels = get_labels('test.arff');
	my @org_list = get_org_list('test.arff');
	my @out_list = get_out_list('out.txt');	
	my %labels_hash = map{$labels[$_],$_}(0..$#labels);
	map{
		for my $label(keys %labels_hash){
			next if $_ =~ /^\./;
			next if $_ =~ /^\*/;
			next if $_ =~ /^\+/;
			next if $_ =~ /^\\/;
			$_ = $label if $label =~ /^$_/s;
		}
	}@out_list;
	@out_list = grep{ $_ !~ /^\./ && $_ !~ /^\*/ && $_ !~ /^\+/ && $_ !~ /^\\/}@out_list;
	
	if ($#labels == 0 && $labels[0] =~ /REAL/i){
		@org_list = grep{$_ || looks_like_number($_)}@org_list;
		@out_list = grep{$_ || looks_like_number($_)}@out_list;
	}
	else{
		@org_list = grep{exists($labels_hash{$_})}@org_list;
		@out_list = grep{exists($labels_hash{$_})}@out_list ;
	}
	if ($#out_list != $#org_list){
		open(FID,'out.txt.pre');
		#print FID 'the size is not match between org data and out data';
		print 'the size is not match between test data (',$#org_list,') and the output (',$#out_list,')',"\n";
		close FID;
	}
	else
	{
		rename('out.txt','out.txt.pre');
	}
}
else{
	#judge if the 3rd program get the arff data directly
	if (isarff('out.txt')){
		if(withlabel('out.txt')){
			open FID,'>out.txt.arff';
			close FID;
		}
		rename('out.txt','out.txt.arff');
	}
	else{
		if ($step eq 'clu'){
			my ($out_number,$seed) = @details;
			if (-e 'data.arff'){
				analysis_data('data.arff','data.info');
				process_clu('out.txt','data',$out_number,$seed) ;
			}else{
				analysis_data('test.arff','test.info');
				process_clu('out.txt','test',$out_number,$seed) ;
			}
		}
		elsif($step eq 'fea'){
			analysis_data('data.arff','data.info');
			my ($out_number , $feautre_threshold) = @details;
			process_fea('out.txt','data',"$out_number","$feautre_threshold");
		}
	}
}

sub uncompressdir{
	#uncompress files to folder
	#input file is files.tgz
	my $in = "files.tgz";
	my $tar = Archive::Tar -> new;
	$tar -> read($in);
	$tar -> extract();
}

sub isarff{
	#judge if the file is arff format
	my $filename = $_[0];
	open(FID,$filename);
	my $isarff = 0;
	while (my $line = <FID>){
		if ($line =~ /\@RELATION/i){
			$isarff++;
		}
		elsif ($line =~ /\@ATTRIBUTE/i){
			$isarff++;
		}
		elsif ($line =~ /\@DATA/i){
			$isarff++;
		}
	}
	close FID;
	my ($instance_out,$attribute_out) = analysis_data($filename);
	#open (FID,'data.info');
	#my ($instance_org,$attribute_org);
	#while (my $line = <FID>){
#		if ($line =~ /number of attribute is (\d+)/){
#			$attribute_org = $1;
#		}
#		elsif ($line =~ /number of instance is (\d+)/){
#			$instance_org = $1;
#		}
#	}
#	close FID;
	if (!$instance_out || $instance_out <= 0 || !$attribute_out || $attribute_out <= 0){
		$isarff = 0;
	}	
	return $isarff;
}

sub process_clu{
	#process cluster output
	my ($outfile_name, $previous_name, $out_number , $seed) = @_;
	if (!$seed){
		$seed = 1;
	}
	elsif ($seed =~ /rand/){
		$seed = int(rand() * 100);
	}
	my $line; my $control = 0;my $label;
	
	my $org_name = $previous_name . '.arff';
	my $org_name_path = "$org_name";
	my $outfile_name_path = "./$outfile_name";
	my @lines_out; my @lines_os;
	#a simple way in dealing with the situation when $outnumber is 'all'  
	if ($out_number eq 'all'){
		my $outdata_name_path = "$outfile_name" . '.arff';
		my $outdata_name_os_path = "$outfile_name" . '.statue';
		open(FID_Org,$org_name_path);		
		open(FID_Out,">$outdata_name_path");
		open(FID_Os,">$outdata_name_os_path");
		my $instance_count = 0;
		while ($line = <FID_Org>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line =~ m/^\@data/i){
				$control = 1;
				#print FID_Out $line;
				push @lines_out,$line;
			}
			elsif($control == 1){
				if ($line =~ m/^%/){
					$control = 0;
					#print FID_Out $line;
					push @lines_out,$line;
					next;
				}
				$instance_count++;
				$line =~ s/\n//;#remember add \n in the end		
				my @line_datas = split(m/,/,$line);
				$label = pop(@line_datas);
				#print FID_Out "$line\n";
				push @lines_out,"$line\n";
				#print FID_Os "Instance$instance_count $label 0\n";
				push @lines_os,"Instance$instance_count $label 0\n";
			}
			else{
				#print FID_Out $line;
				push @lines_out,$line;
			}
			if ($#lines_out > 500){
				print FID_Out @lines_out;
				@lines_out = ();
			}
			if ($#lines_os > 500){
				print FID_Os @lines_os;
				@lines_os = ();
			}
		}
		print FID_Out @lines_out;
		print FID_Os @lines_os;
		close FID_Out;
		close FID_Os;
		return 0;
	}
	#read the orgdata once
	####
	#reanalysis the statue of the data
	####
	my $type = 1;
	
	my $org_class_num; my $total_it; my @types;
	#my ($total_it,$data_attribute,$data_miss,@types)=analysis_data($org_name_path);
	#$type = shift(@types);
	my $data_statue_name_path = "./$previous_name" . '.info';
	open(FID_Info,$data_statue_name_path);	
	while ($line = <FID_Info>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/number of instance is (\d+)/){$total_it = $1;}
		elsif($line =~ m/responce data type is for regress/){$type = 0;}
		elsif($line =~ m/have (\d+) classes: ([^\n]+)/ && $type == 1){
			$org_class_num = $1;
			@types = split(m/,/,$2);
		}		
	}
	close FID_Info;
	
	
	my $out_num;
	my $percent;
	if ($out_number < 1){$out_num = $total_it * $out_number; $percent = $out_number;}
	else { $out_num = $out_number;  $percent = $out_number / $total_it;}
	###########################################################################################################################
	###########################################################################################################################
	#store the classes
	my @classes;
	my $clu_out_its = 0;
	open(FID , $outfile_name_path);
	while ($line = <FID>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if($line =~ m/^\d+\s+([^\s]+)\s*\n/){
			$clu_out_its++;
			if(@classes){
				if (grep{$_ eq $1}@classes){}
				else{
					push(@classes,$1);
				}
			}
			else{push(@classes,$1);}
		}
		elsif($line =~ m/^(\w+)\n/){
			#The format for 3rd-party program
			$clu_out_its++;
			if(@classes){
				if (grep{$_ eq $1}@classes){}
				else{
					push(@classes,$1);
				}
			}
			else{push(@classes,$1);}
		}
	}
	close FID;
	if ($total_it != $clu_out_its){return 1;}
	###########################################################################################################################
	###########################################################################################################################
	#analysis the output number of each class
	#the @per_class_num will have dimention m*n if the data have m labels and the cluster output has n classes. 
	my @per_class_num ;
	my $i;
	#my $label;
	my $position;
	my $position_c;
	
	open(FID_Org,$org_name_path);
	open(FID , $outfile_name_path);
	$control = 0;
	while ($line = <FID_Org>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@data/i){
			$control = 1;
		}
		elsif($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
				next;
			}
			$line =~ s/\n//;
			my @line_datas = split(m/,/,$line);
			$label = pop(@line_datas);
			if ($type == 1){$position = find_position($label,@types);}
			else {$position = 0;}
			my $line1 = <FID>;
			if ($^O !~ m/win/){$line1 =~ s/\r\n$/\n/;}
			if ($line1 =~ m/^\d+\s+([^\s]+)\s*\n/){
				$position_c = find_position($1,@classes);
			}
			elsif ($line1 =~ m/^(\w+)\n/){
				$position_c = find_position($1,@classes);
			}
			#a line for a label, a row responce the number of the label in a class
			$per_class_num[$position][$position_c]++;
		}
	}
	close FID;
	close FID_Org;
	
	#generate the random lists
	#label i whth class j crosspond to the $rand_seq{i j} 
	#my @rand_seq;
	my %rand_seq; my $rand_seq_count = 0;
	my $rows = $#per_class_num;
	#my $cloumns = $#{$per_class_num[0]};
	my $cloumns = 0;
	map{
		$cloumns = $#{$_} if $cloumns < $#{$_};
	}@per_class_num;
	#change @per_class_num to matrix
	map{
		my $sub_row = $_;
		map{
			$per_class_num[$sub_row][$_] = 0 if !$per_class_num[$sub_row][$_];
		}0..$cloumns;
	}0..$rows;
	my $j;
	for $i (0..$rows){
		for $j (0..$cloumns){
			$rand_seq_count++;
			next if !$per_class_num[$i][$j];
			my @rand_seq1 = randperm($per_class_num[$i][$j],$seed) if $per_class_num[$i][$j];
			my $splice_num = int($per_class_num[$i][$j] * $percent);
			if ($splice_num < 1){$splice_num = 1;}
			@rand_seq1 = splice(@rand_seq1,0,$splice_num);			
			#push(@rand_seq,[@rand_seq1]);
			foreach (@rand_seq1){
				$rand_seq{"$_ $rand_seq_count"}++;
			}
		}
	}
	
	###########################################################################################################################
	###########################################################################################################################
	#begin to write the out file
	my $outdata_name_path = "./$outfile_name" . '.arff';
	my $outdata_name_os_path = "./$outfile_name" . '.statue';
	open(FID_Org,$org_name_path);
	open(FID , $outfile_name_path);
	open(FID_Out,">$outdata_name_path");
	open(FID_Os,">$outdata_name_os_path");
	my $instance_count = 0;
	my $position_sss;my $position_ssy;
	$control = 0;
	my @instance;
	while ($line = <FID_Org>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@data/i){
			$control = 1;
			#print FID_Out $line;
			push @lines_out,$line;
		}
		elsif($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
				#print FID_Out $line;
				push @lines_out,$line;
				next;
			}
			$instance_count++;
			$line =~ s/\n//;#remember add the \n		
			my @line_datas = split(m/,/,$line);
			$label = pop(@line_datas);
			if ($type == 1){$position = find_position($label,@types);}
			else {$position = 0;}		
			my $line1 = <FID>;
			if ($^O !~ m/win/){$line1 =~ s/\r\n$/\n/;}
			if ($line1 =~ m/^\d+\s+([^\s]+)\s*\n/){
				$position_c = find_position($1,@classes);
			}
			elsif ($line1 =~ m/^(\w+)\n/){
				$position_c = find_position($1,@classes);
			}
			$instance[$position][$position_c] += 1;
			#the position is $position * ($cloumns + 1) + $1
			$position_sss = $instance[$position][$position_c];
			$position_ssy = $position * $cloumns + $position + $position_c + 1;
			if (exists($rand_seq{"$position_sss $position_ssy"})){
				#print FID_Out "$line\n";
				push @lines_out,"$line\n";
				#print FID_Os "Instance$instance_count $label $classes[$position_c]\n";
				push @lines_os,"Instance$instance_count $label $classes[$position_c]\n";
			}
		}
		else{
			#print FID_Out $line;
			push @lines_out,$line;
		}
		if ($#lines_out > 500){
			print FID_Out @lines_out;
			@lines_out = ();
		}
		if ($#lines_os > 500){
			print FID_Os @lines_os;
			@lines_os = ();
		}
	}
	print FID_Out @lines_out;
	print FID_Os @lines_os;
	close FID;
	close FID_Org;
	close FID_Out;
	close FID_Os;
		
	return 0;
}

sub find_position{
	my ($find_val,@find) = @_;
	my $out = -1;
	my @position = grep{$find[$_] eq $find_val}(0..$#find);
	if(@position){$out = $position[0]};
	return($out);
}

sub analysis_data{
	my ($data_name_path , $out_data_path) = @_;
	#get the infomation of the data
	#output:
	#instances isclassify instances attributes has_miss_data
	my $attribute = 0;
	my $control = 0;
	my $miss = 0;
	my $instance = 0;
	my $attribute_detail;
	my @classes, my $classes_num = 1;
	my $is4class = 1;
	open(FID,"$data_name_path");
	open(FID_OUT,">$out_data_path") if $out_data_path;
	while (my $line = <FID>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@attribute/i && $control == 0){
			$attribute++;
			$attribute_detail = $line;
		}
		elsif ($line =~ m/^\@data/i){
			$control = 1;
			print FID_OUT "number of attribute is $attribute\n" if $out_data_path;
			if($attribute_detail =~ m/\@attribute\s+[^\s]+\s+\{([^\}]+)\}/i){
				@classes = split(m/,/,$1);
				$classes_num = $#classes + 1;
				print FID_OUT "responce data type is for classify\nhave $classes_num classes: $1\n" if $out_data_path;
			}
			else{
				print FID_OUT "responce data type is for regress\n" if $out_data_path;
				$is4class = 0;
			}
		}
		elsif ($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
				next;
			}
			if ($line =~ m/^\s+$/ && $control && !$instance){
				next;
			}			
			my @elements = split /,/,$line; 
			if ($#elements == $attribute - 1){
				$instance++;
			}
			if ($line =~ m/\?/ && $miss == 0){
				$miss = 1;
			}
			
		}
	}
	print FID_OUT "number of instance is $instance\n" if $out_data_path;
	print FID_OUT "if exist missing data $miss\n" if $out_data_path;
	close FID;
	close FID_OUT;
	if ($is4class == 0){
		return ($instance,$attribute,$miss,$is4class);
	}
	else{
		return ($instance,$attribute,$miss,$is4class,@classes);
	}
}

sub randperm{
	#generate the pseudorandom number list
	#use inear congruential generator
	#need the length of list and random seed
	
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

sub process_fea{
	#process the selected variable
	my ($outfile_name, $previous_name, $out_number , $feautre_threshold) = @_;
	$feautre_threshold = 0 if !$feautre_threshold;
	my $org_name = $previous_name . '.arff';
	my $org_name_path = "./$org_name";
	my $outfile_name_path = "./$outfile_name";
	my $data_info_name_path = "./$previous_name" . '.info';
	my @lines_out;
	#this function will process data by the property that if the method is ranker
	#for ranked features, just need to select the first features
	#if not, need to use all of the selected features
	#some times the method would select no feature, this time return will a message
	
	if ($out_number eq 'all'){
		my $outdata_name_path = "./$outfile_name" . '.arff';
		my $outdata_name_os_path = "./$outfile_name" . '.statue';
		open(FID_Org,$org_name_path);		
		open(FID_Out,">$outdata_name_path");
		open(FID_Os,">$outdata_name_os_path");
		my $instance_count = 0;
		while (my $line = <FID_Org>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			#print FID_Out $line;
			push @lines_out,$line;
			if ($#lines_out > 500){
				print FID_Out @lines_out;
				@lines_out = ();
			}
		}
		print FID_Out @lines_out;
		close FID_Out;
		close FID_Org;
		print FID_Os 'use attributes : all';
		close FID_Os;
		return 0;
	}
	########
	########
	#analysis the outcome of method
	open(FID_Val,$outfile_name_path) || die('can not open file');
	my $line;
	my @attributes;
	my $fold_control = 0;#judge if method use n-fold in feature selection
	my $pca_s = 0;#switch of PCA
	my $lsa_s = 0;#switch of LSA
	my @eigen_m;#eigenvector matrix for PCA
	#my @sv;#SingularValue vector
	my $lsa_num = 0;
	#my %hash_lsa_label;#left singular vectors ---- label in LSA
	#my %hash_position_labels;#record the sequence of the labels
	my %hash_var_names, my $hash_var_names_count;
	#read the out file
	while ($line = <FID_Val>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		
		if ($line =~ m/Selected attributes:\s*([^:]+)\s*:/i ){
			@attributes = split(m/,/,$1);
		}
		elsif($line =~ m/number\s+of\s+folds/ && $out_number eq 'nr'){
			$fold_control = 1;
		}
		elsif ($line =~ m/^\s*\d+\(\s*(\d+)\s*%\)\s*(\d+)/ && $fold_control == 1){
			if ($1 / 100 >= $feautre_threshold){push(@attributes,$2);}
		}
		elsif ($line =~ m/average\s+merit\s+average\s+rank/ && $out_number ne 'nr'){
			$fold_control = 2;
		}
		elsif ($line =~ m/^\s*([\d\.]+)\s+\+\-\s+[\d\.]+\s+[\d\.]+\s+\+\-\s+[\d\.]+\s+(\d+)/ && $fold_control == 2){
			push(@attributes,$2) if $1 >= $feautre_threshold;
		}
		elsif ($line =~ m/^Eigenvectors/){$pca_s = 1;}
		elsif ($line =~ m/^[-\s][\d\.]+/ && $pca_s == 1){
			$line =~ s/^\s+//;
			my @sub_eigen = split /\s+/,$line;
			push @eigen_m,[@sub_eigen[0 .. $#sub_eigen - 1]];
			#$hash_var_names_count++;
			$hash_var_names{$sub_eigen[$#sub_eigen]} = $hash_var_names_count++;#the count of list begin with 0
		}
		elsif ($line =~ m/^\s*\n/ && $pca_s == 1){ $pca_s = 2;}
		elsif ($line =~ m/^SingularValue\s+LatentVariable/){$lsa_s = 1;}
#		elsif ($line =~ m/^\s*(-?\d+\.\d+)\s+\d+/ && $lsa_s == 1){
#			push @sv,$1;
#		}
		elsif ($line =~ m/^Instance\#1\s+/i && $lsa_s == 1){
			$lsa_s = 2;
			#open FID_lsa,'>lsa_matrix.txt';
		}
		elsif ($line =~ m/^\s*(-?\d+\.\d+)\s+/ && $lsa_s == 2){
			$line =~ s/\s+$//;
			$line =~ s/^\s+//;
			my @sub_lv = split/\s+/,$line;
			my $sub_label = pop @sub_lv;
			open FID_lsa,">lsa_vectors_$lsa_num" ;
			print FID_lsa join "\n",@sub_lv;
			close FID_lsa;
			$lsa_num++;
		}
		elsif ($line =~ /\s+$/ && $lsa_s == 2){
			$lsa_s = 3;
			#close FID_lsa;
		}
	}
	close FID_Val;	
	$lsa_num--;
	#get the lsa convert matirx
	#LatentVariable#(x) / SingularValue(x)
#	if ($lsa_s){
#		for (keys %hash_position_labels){
#			my $label = $_;
#			map{
#				${$hash_position_labels{$label}}[$_] /= $sv[$_];
#			}0..$#sv;
#		}
#		$lsa_num = scalar @sv;
#	}
	
	
	#modify @arrtibutes by the property
	if ($out_number ne 'nr'){
		@attributes = splice(@attributes,0,$out_number);}
	#return a message if no feature is selected
	if (! @attributes){
		#move("$main::prog_dir/$main::name/status/$outfile_name_path", "$main::prog_dir/$main::name/err");
		return 'no_attribute';
	}
	#analysis the infomation file
	my $data_statue_name_path = "./$previous_name" . '.info';
	my $total_it;my $is4class = 1;
	open(FID_Info,$data_statue_name_path);	
	while ($line = <FID_Info>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/number of attribute is (\d+)/){
			#@attributes = (@attributes , $1);
			$total_it = $1;
		}
		elsif($line =~ m/responce data type is for regress/){
			$is4class = 0;
		}
	}
	close FID_Info;
#	@attributes = (@attributes , $total_it) if $is4class;
	@attributes = (@attributes , $total_it);
	@attributes = map{$_ - 1}@attributes;
	@attributes = sort{$a<=>$b}@attributes;
	
	#begin to write the output file
	my $control = 0;
	my $att_num = 0;
	my @sub_att;
	my $outdata_name_path = "./$outfile_name" . '.arff';	
	my @attributes_name;
	#my %hash_binary_class_lsa;
	open(FID_Org,$org_name_path);
	open(FID_Out,">$outdata_name_path");
	my $instance_count = 0;
	my @lsa_vector_files;
	map{
		open $lsa_vector_files[$_],'lsa_vectors_'.$_;
	}0..$lsa_num;
	while ($line = <FID_Org>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@ATTRIBUTE/i){
			#$att_num++;
			#the begin of the index is 0
			if ($pca_s || $lsa_s){
				$line =~ m/^\@ATTRIBUTE\s+([^\s]+)\s/i;
				push @attributes_name,$1;
			}
#			if ($lsa_s && $line =~ m/^\@ATTRIBUTE\s+(\S+)\s+\{([^\}]+)/i){
#				
#				my $sub_name = $1;
#				my @sub_class = split /,/,$2;
#				$sub_name =~ s/[\']//g;
#				map{$_ =~ s/[\'\s]//g;}@sub_class;
#				if (scalar @sub_class == 2){
#					$hash_binary_class_lsa{$sub_name . '=' . $sub_class[0]} = 0;
#					$hash_binary_class_lsa{$sub_name . '=' . $sub_class[1]} = 1;
#				}
#			}

			if (grep{$_ == $att_num}@attributes){
				#print FID_Out $line;
				push @lines_out,$line if (!$pca_s && !$lsa_s) || $att_num == $attributes[$#attributes];
				push @lines_out,'@ATTRIBUTE Val' . $att_num . ' real' . "\n" if ($pca_s || $lsa_s) && $att_num != $attributes[$#attributes];
			}
			$att_num++;
		}
		elsif ($line =~ m/^\@data/i){
			$control = 1;
			#print FID_Out $line;
			push @lines_out,$line;
		}
		elsif ($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
				#print FID_Out $line;
				push @lines_out,$line;
				next;
			}
			$line =~ s/\n//;
			@sub_att = split(m/,/,$line);
			my $label = $sub_att[$#sub_att];
			@sub_att = get_pca(\@attributes_name,\@eigen_m,\%hash_var_names,@sub_att) if $pca_s;
			#@sub_att = get_lsa(\@attributes_name,\%hash_position_labels,\%hash_binary_class_lsa,$lsa_num,@sub_att) if $lsa_s;
			@sub_att = get_lsa(\@lsa_vector_files,pop @sub_att) if $lsa_s;
			
			if ($#sub_att < $attributes[$#attributes]){
				@sub_att = @sub_att[@attributes];
				@sub_att = grep{$_}@sub_att;
				push @sub_att,$label;
				#print FID_Out join(',',@sub_att);print FID_Out "\n";
				push @lines_out,join(',',@sub_att) . "\n";
			}
			else{
				#print FID_Out join(',',@sub_att[@attributes]);print FID_Out "\n";
				push @lines_out,join(',',@sub_att[@attributes]) . "\n";
			}
		}
		else {
			#print FID_Out $line;
			push @lines_out,$line;
		}		
		if ($#lines_out > 500){
			print FID_Out @lines_out;
			@lines_out = ();
		}
	}
	print FID_Out @lines_out;
	close FID_Org;
	close FID_Out;
	
	map{close $_;}@lsa_vector_files;
	
	#write the statue file
	my $outdata_name_os_path = "./$outfile_name" . '.statue';
	open(FID_S,">$outdata_name_os_path");
	print FID_S 'use attributes : ',join(',',@attributes),"\n";
	return 0;
}

sub get_pca{
	#get the deatail when use PCA
	my ($attributes_name_l,$eigen_m_l,$hash_var_names_l,@sub_att) = @_;
	my ($i,$j,$k);
	my @out;
	
	for $i (0..$#{$$eigen_m_l[0]}){
		my $each_pca = 0;
		for $j (0..$#sub_att - 1){
			if (looks_like_number($sub_att[$j])){
				$each_pca += $sub_att[$j] * $$eigen_m_l[$$hash_var_names_l{$$attributes_name_l[$j]}][$i] if exists $$hash_var_names_l{$$attributes_name_l[$j]};
			}else{
				$k = $$attributes_name_l[$j] . '=' . $sub_att[$j];
				$each_pca += 1 * $$eigen_m_l[$$hash_var_names_l{$k}][$i];
			}
		}
		push @out,$each_pca;
	}
	map{
		if ($_ =~ /nan/i || $_ =~ /inf/i){
			if ($_ =~ /-/){
				$_ = -1 * 10**30 ;
			}
			else{
				$_ = 1 * 10**30 ;
			}
		}
	}@out;
	push @out,$sub_att[$#sub_att];
	return @out;
}

sub get_lsa{
	#get the deatail when use LSA
	my ($lsa_vector_files_l , $last) = @_;
	my @out;
	map{
		my $line = <$_>;
		$line =~ s/\s+$//;
		push @out,$line;
	}@$lsa_vector_files_l;
	return @out,$last;
}

sub get_labels{
	#get labels of train data
	my ($data_name) = $_[0];
	open(FID,"$data_name");
	my $line;
	my @labels;
	while ($line = <FID>){
		if ($line =~ /^\@ATTRIBUTE\s+[^\s]+\s+\{([^\}]+)/i){
			@labels = split(/,/,$1);
		}
		#consider of the regress data
		elsif ($line =~ /^\@ATTRIBUTE\s+[^\s]+\s+(REAL)/i){
			@labels = ($1);
		}
		if ($line =~ /^\@data/i){last;}
	}
	close FID;
	return @labels;
}

sub get_org_list{
	#get labels/responses of orgdata
	my $data_name = $_[0];
	open(FID,"$data_name");
	my $line;
	my @org_list;
	my $switch, my @elements;
	while ($line = <FID>){
		if ($line =~ /^\@data/i){
			$switch = 1;
		}
		elsif ($switch && $switch == 1){
			if ($line =~ /^([^\n%]+)\n/){
				@elements = split(/,/,$1);
				push (@org_list,pop(@elements));
			} 
			elsif ($line =~ /^%/){$switch = 0;}
		}
	}
	close FID;
	return @org_list;
}

sub get_out_list{
	#get the predict list
	
	my $out_file_name = $_[0];
	open(FID,"$out_file_name");
	my $line;
	my @out_list;
	while ($line = <FID>){
		if ($line =~ /\s+\d+\s+\d+:[^\s]+\s+\d+:([^\s]+)/){
			push (@out_list,$1);
		}
		#for regress data
		if ($line =~ /^\s+\d+\s+[-\d\.]+\s+([-\d\.]+)/){
			push (@out_list,$1);
		}
		#simplified format
		elsif ($line =~ /^([^\s]+)\s*\n$/){
			push (@out_list,$1);
		}
	}
	close FID;
	return @out_list;
}

sub dircopy{
	#Copy the folder.
	my ($dir_source , $dir_target) = @_;
	mkdir $dir_target if !-d $dir_target;
	my @files = <$dir_source/*>;
	while ($#files > -1){
		my $file = $files[$#files];
		my $file_name = $file;
		$file_name =~ s/^$dir_source\///s;
		if (-f $file){
			copy($file , "$dir_target/$file_name" ) ;
			pop @files;
		}
		elsif (-d $file){
			my @subfiles = <$dir_source/$file_name/*>; 
			mkdir "$dir_target/$file_name";
			pop @files;
			if ($#subfiles > -1){
				push @files,@subfiles;
			}
		}
	}
}

sub withlabel{
	my $out_flie = $_[0];
	my $last_label_data;
	my $last_label_out;
	open FID_data,'data.arff';
	while (my $line = <FID_data>){
		if ($line =~ m/\@attribute\s+([^\s]+)/i){
			$last_label_data = $1;
		}
	}
	close FID_data;
	open FID_out,$out_flie;
	while (my $line = <FID_out>){
		if ($line =~ m/\@attribute\s+([^\s]+)/i){
			$last_label_out = $1;
		}
	}
	close FID_out;
	return 1 if $last_label_data ne $last_label_out;
	return 0 if $last_label_data eq $last_label_out;
}



