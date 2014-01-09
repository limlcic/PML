package pml::result;
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

use warnings;
use strict;
use File::Copy;
use Cwd;
use threads;
use threads::shared;
require Exporter;
use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter);
$VERSION = '1.00';
@EXPORT =qw (analysis_out_files show_process_err show_out_files_progress init_pml_result);

our @acc_names = ('Name' , 'TPR' , 'FPR' , 'ACC' , 'SPC' , 'PPV' , 'NPV' , 'FDR' , 'MCC' , 'F1');
our @acc_names_with_overall = ('Name' , 'TPR' , 'FPR' , 'ACC' , 'SPC' , 'PPV' , 'NPV' , 'FDR' , 'MCC' , 'F1' , 'TPR_O' , 'FPR_O' , 'ACC_O' , 'SPC_O' , 'PPV_O' , 'NPV_O' , 'FDR_O' , 'MCC_O' , 'F1_O');
our @acc_names_r = ('Name' ,'CC','RMSE','MAE','RAE','RRSE');
#our @related_names;

our (%hash_clu_num , %hash_num_clu , %hash_fea_num , %hash_num_fea , %hash_tt_num , %hash_num_tt);
our @related_names = (\%hash_clu_num , \%hash_num_clu , \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt);
#get_related_name(\%hash_clu_num , \%hash_num_clu , \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt);

#*******************************************************************
#
# Function Name: init_pml_result()
#
#
# Description: 
#		Initialize some global variables for this module.
#
# Parameters:
#
# 		None
#		
# Return:
#
#		None
#
#*********************************************************************

sub init_pml_result{
	our (%hash_clu_num , %hash_num_clu , %hash_fea_num , %hash_num_fea , %hash_tt_num , %hash_num_tt);
	get_related_name(\%hash_clu_num , \%hash_num_clu , \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt);
}

#*******************************************************************
#
# Function Name: read_out_file($task_name)
#
#
# Description: 
#		Read the output file of the task; get the related labels
#		and information for analysis.
#
# Parameters:
#
# 		$task_name: The name of the task
#		
# Return:
#
#		4 references of ARRAY:
#		@org_list: The labels of the data.
#		@out_list: The predicted labels.
#		%labels_hash: The sequences of the instances with labels.
#		@labels: The labels of classes.
#
#*********************************************************************

sub read_out_file{
	#Read the output file of the task; get the related labels and information for analysis.
	my $out_file_name = $_[0];
	my $data_name = get_data_name($out_file_name);
	my @labels = get_labels($data_name);
	my @org_list = get_org_list($data_name);
	my @out_list = get_out_list($out_file_name);
	
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
	
	die 'the size is not match between org data and out data about file ' . $out_file_name . "\n"
	if $#org_list != $#out_list;
	
	return([@org_list],[@out_list],[%labels_hash],[@labels]);
}

#*******************************************************************
#
# Function Name: get_data_name($task_name)
#
#
# Description: 
#		Get the related test data names of specified modeling task.
#		example:
#		name_train_clu_0.0_1_fea_1_0_tt_1.0_inner_1_outer_0
#		to:
#		name_train_clu_0.0_1_fea_1_0_inner_1_outer_0_test.arff
#
# Parameters:
#
# 		$task_name: The name of the task
#		
# Return:
#
#		The related test data name
#
#*********************************************************************

sub get_data_name{
	#Get the related test data names of specified modeling task.
	#example:
	#name_train_clu_0.0_1_fea_1_0_tt_1.0_inner_1_outer_0
	#to:
	#name_train_clu_0.0_1_fea_1_0_inner_1_outer_0_test.arff
	my $out_file_name = $_[0];
	my $data_name;
	$out_file_name =~ s/^$main::name//s;
	$out_file_name =~ s/^_train_//;
	my @elements = split(/_/,$out_file_name);
	#$data_name = shift(@elements);
	$data_name = $main::name . '_train';
	my @element_t = grep{$elements[$_] =~ /^tt/}(0..$#elements);
	splice(@elements,$element_t[$#element_t],2);
	$data_name = join('_',($data_name,@elements));
	$data_name .= '_test.arff';
	return $data_name;
}

#*******************************************************************
#
# Function Name: get_data_name($data_name)
#
#
# Description: 
#		Get the labels of the specified data.
#
# Parameters:
#
# 		$data_name: The name of the ARFF data file
#		
# Return:
#
#		ARRAY of labels
#
#*********************************************************************

sub get_labels{
	#Get the labels of the specified ARFF data file.
	my ($data_name) = $_[0];
	open(FID,"$main::prog_dir/results/$main::name/data/$data_name");
	my $line;
	my @labels;
	while ($line = <FID>){
		if ($line =~ /^\@ATTRIBUTE\s+[^\s]+\s+\{([^\}]+)/i){
			@labels = split(/,/,$1);
		}
		elsif ($line =~ /^\@ATTRIBUTE\s+[^\s]+\s+(REAL)/i){
			@labels = ($1);
		}
		if ($line =~ /^\@data/i){last;}
	}
	close FID;
	return @labels;
}

#*******************************************************************
#
# Function Name: get_org_list($data_name)
#
#
# Description: 
#		Get the labels of each instances in the specified data file
#
# Parameters:
#
# 		$data_name: The name of the ARFF data file
#		
# Return:
#
#		ARRAY of labels
#
#*********************************************************************

sub get_org_list{
	#Get the label of each instance in the specified data file.
	my $data_name = $_[0];
	open(FID,"$main::prog_dir/results/$main::name/data/$data_name");
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

#*******************************************************************
#
# Function Name: get_out_list($out_file_name)
#
#
# Description: 
#		Get the labels of each instances in the specified prediction (modeling output) file
#
# Parameters:
#
# 		$out_file_name: The name of the prediction file
#		
# Return:
#
#		ARRAY of predicted lables
#
#*********************************************************************

sub get_out_list{
	#Get the label of each instance in the specified modeling output file.
	
	my $out_file_name = $_[0];
	open(FID,"$main::prog_dir/results/$main::name/complete/results/$out_file_name");
	my $line;
	my @out_list;
	while ($line = <FID>){
		if ($line =~ /\s+\d+\s+\d+:[^\s]+\s+\d+:([^\s]+)/){
			push (@out_list,$1);
		}
		#template of weka
		if ($line =~ /^\s+\d+\s+[-\d\.]+\s+([-\d\.]+)/){
			push (@out_list,$1);
		}
		#template of simple input
		elsif ($line =~ /^([^\s]+)\s*\n$/){
			push (@out_list,$1);
		}
	}
	close FID;
	return @out_list;
}

#*******************************************************************
#
# Function Name: cal_acc_c([@org_list] , [@out_list] , [%labels_hash] , [@labels])
#
#
# Description: 
#		Calculate the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 through the modeling output
#		All of the input parameters are generated by function read_out_file()
#
# Parameters:
#
# 		@org_list: The labels of the data.
#		@out_list: The predicted labels.
#		%labels_hash: The sequences of the instances with labels.
#		@labels: The labels of classes.
#		
# Return:
#
#		Calculate the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 through the modeling output
#
#*********************************************************************

sub cal_acc_c{
	#Calculate the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 through the modeling output
	my @org_list = @{$_[0]};
	my @out_list = @{$_[1]};
	my %labels_hash = @{$_[2]};
	my @labels = @{$_[3]};
	my @confu_matrix;
	#initialize the confusion martix
	my $x;
	@confu_matrix = map{
		$x = $_;
		[map{$confu_matrix[$x][$_] = 0}0 .. $#labels];
	}0 .. $#labels;
	#fill the confusion matrix£¬horizontal is the true value, list is the predicted value
	#for example, the horizontal is 2 and list is 1 means the original is 2 but the predicted is 1 
	my $i;
	for $i(0..$#org_list){
		$confu_matrix[$labels_hash{$org_list[$i]}][$labels_hash{$out_list[$i]}]++;
	}
	my @out_accs;
	for $i(0..$#labels){
		push @out_accs,[$labels[$i],get_acc_single([@confu_matrix],$i)];
	}
	return ([@out_accs],[@confu_matrix],[@labels]);
}

#*******************************************************************
#
# Function Name: cal_acc_r([@org_list] , [@out_list] )
#
#
# Description: 
#		Calculate the CC, MAE, RMSE, RAE, RRSE through the modeling output
#
# Parameters:
#
# 		@org_list: The labels of the data.
#		@out_list: The predicted labels.
#		
# Return:
#
#		The values of the evaluation criterions
#
#*********************************************************************

sub cal_acc_r{
	#Calculate the CC, MAE, RMSE, RAE, and RRSE through the modeling output
	my @org_list = @{$_[0]};
	my @out_list = @{$_[1]};
	my $org_mean = mean_list(@org_list);
	my $out_mean = mean_list(@out_list);
	#RMSE
	my @SE = map{($org_list[$_] - $out_list[$_]) ** 2}0..$#org_list;
	my $RMSE = sqrt(mean_list(@SE));
	#MAE
	my @AE = map{abs($org_list[$_] - $out_list[$_])}0..$#org_list;
	my $MAE = mean_list(@AE);
	#RAE
	my $SAE = 0; map{$SAE += $_}@AE;
	my $RAE = 0; map{$RAE += abs($_ - $org_mean)}@org_list; 
	$RAE = $SAE / $RAE if $RAE != 0;
	$RAE = 'nan' if $RAE == 0;
	#RRSE
	my $SSE = 0;map{$SSE += $_}@SE;
	my $RRSE = 0; map{$RRSE += ($_ - $org_mean) ** 2}@org_list; 
	$RRSE = sqrt($SSE / $RRSE) if $RRSE != 0;
	$RRSE = 'nan' if $RRSE == 0;
	#CC
	my $CC1 = 0; map{$CC1 += ($org_list[$_] - $org_mean) * ($out_list[$_] - $out_mean)}0..$#org_list;
	my $CC2 = 0; map{$CC2 += ($_ - $org_mean) ** 2}@org_list;
	my $CC3 = 0; map{$CC3 += ($_ - $out_mean) ** 2}@out_list;
	my $CC;
	$CC = $CC1 / sqrt($CC2 * $CC3) if $CC2 * $CC3 != 0;
	$CC = -1 if $CC2 * $CC3 == 0;
	
	$CC = round($CC,$main::round_l + 1);
	$RMSE = round($RMSE,$main::round_l + 1);
	$MAE = round($MAE,$main::round_l + 1);
	$RAE = round($RAE,$main::round_l + 1);
	$RRSE = round($RRSE,$main::round_l + 1);
	return ($CC,$RMSE,$MAE,$RAE,$RRSE);
}

#*******************************************************************
#
# Function Name: mean_list( @list )
#
#
# Description: 
#		Get an average value of an ARRAY
#
# Parameters:
#
# 		@list: An ARRAY with numbers
#		
# Return:
#
#		The average value
#
#*********************************************************************

sub mean_list{
	#get an average value of an ARRAY
	my @list = @_;
	my $out = 0;
	map{$out += $_}@list;
	$out /= $#list + 1;
	return $out;
}

#*******************************************************************
#
# Function Name: get_acc_single([@confu_matrix] , $label_count)
#
#
# Description: 
#		Get the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 for the specified label
#
# Parameters:
#
# 		@confu_matrix: The confusion matrix of the predicted task
#		$label_count: The serial number of the label which is used
#				 to generated the outputs.
#		
# Return:
#
#		The values of the evaluation criterions
#
#*********************************************************************

sub get_acc_single{
	#Get the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 for the specified label.
	#$i specify the lable as the positive (P)
	my @confu_matrix = @{$_[0]};
	my $i = $_[1];
	my $TP = $confu_matrix[$i][$i];
	my $FP = 0; map{$FP += $confu_matrix[$_][$i]}0 .. $#confu_matrix;
	$FP -= $TP;
	my $FN = 0; map{$FN += $confu_matrix[$i][$_]}0 .. $#confu_matrix;
	$FN -= $TP;
	my $x;
	my $TN = 0;
	
	map{$x = $_;
		[map{$TN += $confu_matrix[$x][$_]}0 .. $#confu_matrix]
	}0 .. $#confu_matrix;
	$TN -= ($TP + $FN + $FP);
	
	my $P = $TP + $FN, my $P1 = $TP + $FP;
	my $N = $FP + $TN, my $N1 = $TN + $FN;
	my $TPR = $TP / $P if $P != 0;	$TPR = 0 if $P == 0;
	my $FPR = $FP / $N if $N != 0;	$FPR = 1 if $N == 0;
	
	my $ACC;
	$ACC = ($TP + $TN) / ($P + $N) if $P + $N != 0;
	$ACC = 0 if $P + $N == 0;
	
	my $SPC = 1 - $FPR;
	my $PPV = $TP / $P1 if $P1 != 0;	$PPV = 0 if $P1 == 0;
	my $NPV = $TN / $N1 if $N1 != 0;	$NPV = 0 if $N1 == 0;
	my $FDR = $FP / $P1 if $P1 != 0;	$FDR = 1 if $P1 == 0;
	my $MCC = ($TP * $TN - $FP * $FN) / sqrt($P * $N * $P1 * $N1) if $P * $N * $P1 * $N1 != 0;
	$MCC = -1 if $P * $N * $P1 * $N1 == 0;
	my $F1 = 2 * $TP / ($P + $P1) if $P + $P1 != 0;	$F1 = -1 if $P + $P1 == 0; 
	return ($TPR , $FPR , $ACC , $SPC , $PPV , $NPV , $FDR , $MCC , $F1);
}

#*******************************************************************
#
# Function Name: analysis_out_files()
#
#
# Description: 
#		Analysis the results of all the tasks, then generate 
#		the output html files, related trees and tables.
#
# Parameters:
#
# 		None
#		
# Return:
#
#		None
#
#*********************************************************************

sub analysis_out_files{
	#Analyze the results of all the tasks, then generate the output html files, related trees and tables.

	#hash tables for tree, 
	#isok, parents nodes, nodes
	my %hash_isok, my %hash_p, my %hash_n;
	share %hash_isok;
	
	print "\nAll of the computing tasks are completed, start to generate the outputs...\n" if !$main::silent;
	
	#start
	my $pwd = getcwd();
	my $complete_dir = "$main::prog_dir/results/$main::name/complete";
	my $err_dir = "$main::prog_dir/results/$main::name/err";
	chdir $complete_dir;
	my @complete_files = < * >;
	map{$hash_isok{$_} = 1}@complete_files;
	chdir $pwd;
	chdir $err_dir;
	my @err_files = < * >;
	map{$hash_isok{$_} = 0}@err_files;
	chdir $pwd;
	@complete_files = grep{ -f "$complete_dir/$_"}@complete_files;
	@err_files = grep{ -f "$err_dir/$_"}@err_files;
	#start to get nodes	
	#The first node is 'process tree'£¬thus the count number start with 1
		
	#get names
	my (%hash_clu_num , %hash_num_clu , %hash_fea_num , %hash_num_fea , %hash_tt_num , %hash_num_tt);
	our @related_names = (\%hash_clu_num , \%hash_num_clu , \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt);
	get_related_name(\%hash_clu_num , \%hash_num_clu , \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt);
	#hash table for n-fold and PO
	my %hash_nfold;		my %hash_grid;
	my $file, my @elements, my $node_count = 0;
	my $i, my $p_name, my $step, my $nf_name, my $gd_name;
	my @wait_units;
	
	print "Step 1: analysis the outputs of tasks and gernate the results.\n" if !$main::silent;
	my $complete_jobs = 0;
	my $total_jobs = scalar @complete_files + scalar @err_files;
	
	#parallel parameters
	my (%hash_id_time , %hash_id_name , %hash_name_repeat);
	
	for $i(0..$#main::step){
		for $file(@complete_files,@err_files){
			my $file_elements = $file;
			$file_elements =~ s/^$main::name//s;
			$file_elements =~ s/^_train_//;
			@elements = split /_/,$file_elements;
			@elements = grep{/^[cft]/}@elements;
			if ($#elements == $i){
				if (exists($hash_n{$file})){
					next;
				}
				$node_count++;
				$step = pop @{[grep{/^[cft]/}split /_/,$file]};
				if ($step eq 'tt'){
					$nf_name = get_nf_name($file);
					$gd_name = get_gd_name($nf_name);
					if (!exists($hash_n{$gd_name})){
						$hash_n{$gd_name} = $node_count;
						$hash_grid{$gd_name}++;
						$node_count++;
						if ($i == 0){
							$hash_p{$gd_name} = 0;
						}else{
							$hash_p{$gd_name} = $hash_n{get_parent_name($gd_name)};
						}
					}
					if (!exists($hash_n{$nf_name})){
						$hash_n{$nf_name} = $node_count;
						$hash_nfold{$nf_name}++;
						$node_count++;
						$hash_p{$nf_name} = $hash_n{$gd_name};
					}
					if ($file =~ /_inner_/){
						my $p_name_outer = $file;
						$p_name_outer =~ s/_inner_\d+_/_/;
						if (!exists($hash_n{$p_name_outer})){
							$hash_n{$p_name_outer} = $node_count;
							$node_count++;
							$hash_p{$p_name_outer} = $hash_n{$nf_name};
							push @wait_units,$p_name_outer;
						}
						$hash_p{$file} = $hash_n{$p_name_outer}; 
						$hash_n{$file} = $node_count;						
					}
					else{										
						$hash_p{$file} = $hash_n{$nf_name};
						$hash_n{$file} = $node_count if !exists $hash_n{$file};
					}
				}
				else{
					$hash_n{$file} = $node_count;
					if ($i == 0){
						$hash_p{$file} = 0;
					}else{
						$p_name = get_parent_name($file);
						$hash_p{$file} = $hash_n{$p_name};
					}
				}
					push @wait_units,$file;
			}
#			while (scalar(threads->list()) < $main::core_number && $#wait_units >= 0){
#				my $thread = threads->create("get_relate_file" , $wait_units[0] , \%hash_isok);
#				my $tid = $thread->tid();
#				$hash_id_name{$tid} = $wait_units[0];
#				$hash_id_time{$tid} = time;
#				shift @wait_units;
#			}
#			
#			for my $thread(threads->list(threads::all)){
#				my $tid = $thread->tid();
#				if($thread->is_joinable()){
#					$thread->join();
#					$complete_jobs++;
#					delete $hash_id_name{$tid};
#					delete $hash_id_time{$tid};
#					show_out_files_progress($complete_jobs,$total_jobs) if !$main::silent;
#				}
#				else{
#					if (time - $hash_id_time{$tid} > $main::time_limit_result){
#						push @wait_units,$hash_id_name{$tid};
#						$thread->exit();
#						$hash_name_repeat{$hash_id_name{$tid}}++;
#						die "PML has repeat over 100 times for one result analysis:\n".$hash_id_name{$tid}.
#						"\nplease retry PML or check the parameters.\n" if $hash_name_repeat{$hash_id_name{$tid}} > 100;
#						delete $hash_id_name{$tid};
#						delete $hash_id_time{$tid};
#					}
#				}
#			}

		}
	}
	
#	while ($#wait_units >= 0 || scalar(threads->list()) > 0){
#		while (scalar(threads->list()) < $main::core_number && $#wait_units >= 0){
#			my $thread = threads->create("get_relate_file" , $wait_units[0] , \%hash_isok);
#			my $tid = $thread->tid();
#			$hash_id_name{$tid} = $wait_units[0];
#			$hash_id_time{$tid} = time;
#			shift @wait_units;
#		}
#		foreach my $thread(threads->list(threads::all)){
#			my $tid = $thread->tid();
#			if($thread->is_joinable()){
#				$thread->join();
#				delete $hash_id_name{$tid};
#				delete $hash_id_time{$tid};
#				$complete_jobs++;
#				show_out_files_progress($complete_jobs,$total_jobs) if !$main::silent;
#			}
#			else{
#				if (time - $hash_id_time{$tid} > $main::time_limit_result){
#					push @wait_units,$hash_id_name{$tid};
#					$thread->exit();
#					$hash_name_repeat{$hash_id_name{$tid}}++;
#					die "PML has repeat over 100 times for one result analysis:\n".$hash_id_name{$tid}.
#					"\nplease retry PML or check the parameters.\n" if $hash_name_repeat{$hash_id_name{$tid}} > 100;
#					delete $hash_id_name{$tid};
#					delete $hash_id_time{$tid};
#				}
#			}
#		}
#	}

	while ($#wait_units >= 0 || scalar(threads->list()) > 0){
		while (scalar(threads->list()) < $main::core_number && $#wait_units >= 0){
			my $j = 49;
			$j = $#wait_units if $j > $#wait_units;
			my $thread = threads->create(sub{
				my ($hash_isok_l , @units) = @_;
				@_ = ();
				for (@units){
					get_relate_file($_,$hash_isok_l);
				}
				return 0;
			} , \%hash_isok , @wait_units[0..$j]);
			my $tid = $thread->tid();
			$hash_id_name{$tid} = join ' ',@wait_units[0..$j];
			$hash_id_time{$tid} = time;
			#shift @wait_units;
			splice @wait_units,0,($j+1);
		}
		foreach my $thread(threads->list(threads::all)){
			my $tid = $thread->tid();
			if($thread->is_joinable()){
				$thread->join();
				delete $hash_id_name{$tid};
				delete $hash_id_time{$tid};
				$complete_jobs += 50;
				$complete_jobs = $total_jobs if $complete_jobs > $total_jobs;
				show_out_files_progress($complete_jobs,$total_jobs) if !$main::silent;
			}
			else{
				if (time - $hash_id_time{$tid} > $main::time_limit_result){
					push @wait_units,split(/ /,$hash_id_name{$tid});
					$thread->exit();
					$hash_name_repeat{$hash_id_name{$tid}}++;
					die "PML has repeat over 100 times for one result analysis:\n".$hash_id_name{$tid}.
					"\nplease retry PML or check the parameters.\n" if $hash_name_repeat{$hash_id_name{$tid}} > 100;
					delete $hash_id_name{$tid};
					delete $hash_id_time{$tid};
				}
			}
		}
	}


	print "\ncomplete\n" if !$main::silent;
	
	print "Step 2: generate the cross-validation results.\n" if !$main::silent;
	my @best_accs=analysis_nfold(\%hash_isok,\%hash_n,\%hash_p,\%hash_nfold);
	print "\ncomplete\n" if !$main::silent;
	
	print "Step 3: generate the parameter optimization results.\n" if !$main::silent;
	analysis_grid(\%hash_isok,\%hash_n,\%hash_p,\%hash_grid,\@related_names);
	print "\ncomplete\nStart to generate the web page...\n" if !$main::silent;
	
	#Begin to generate the conclution file
	copy("$main::prog_dir/web/dtree.js","$main::prog_dir/results/$main::name");
	copy("$main::prog_dir/web/style.css","$main::prog_dir/results/$main::name");
	copy("$main::prog_dir/web/tableSort.js","$main::prog_dir/results/$main::name");
	copy("$main::prog_dir/web/logo.gif","$main::prog_dir/results/$main::name/results");
	copy("$main::prog_dir/web/para_classify.html","$main::prog_dir/results/$main::name/results/para_explanation.html") if !$main::regress;
	copy("$main::prog_dir/web/para_regress.html","$main::prog_dir/results/$main::name/results/para_explanation.html") if $main::regress;
	copy("$main::prog_dir/src/processor_single.pl","$main::prog_dir/results/$main::name/processor_single.pl");
	copy("$main::prog_dir/lib/weka.jar","$main::prog_dir/results/$main::name/weka.jar");
	
	dircopy("$main::prog_dir/web/img","$main::prog_dir/results/$main::name/results/img");
	dircopy("$main::prog_dir/web/form","$main::prog_dir/results/$main::name/results/form");
	open (FID_H,">$main::prog_dir/results/$main::name/results" . '.html');
	
	#head
	print FID_H '<!DOCTYPE html>',"\n";
	print FID_H '<html>',"\n",'<head>',"\n",'<title>',"PML Output",'</title>',"\n";
	print FID_H '<style type="text/css">',"\n",'@import url("style.css");',"\n",'</style>',"\n",'</head>',"\n";
	print FID_H '<body>',"\n";
	
	#LOGO
	print FID_H '<a><img src = "results/logo.gif" ></a>',"\n";
	
	#tree	
	print FID_H '<h2>Data processing</h2>',"\n";
	#some description
	if ($#main::step > 0){
		my $steps = join ' ---- ',@main::step;
		$steps =~ s/clu/cluster/;
		$steps =~ s/fea/variable selection/;
		$steps =~ s/tt/modeling/;
		print FID_H 'There are ',$#main::step + 1,' steps in data processing: ',$steps,'<br>',"\n";
	}
	else{
		print FID_H 'This data is used to modeling directly:<br>',"\n";
	}
	my $total_tasks = scalar @complete_files + scalar @err_files;
	print FID_H $total_tasks;
	print FID_H ' tasks' if $total_tasks > 1;
	print FID_H ' task' if $total_tasks == 1;
	print FID_H ' have been excuted in this experiment,<br>',"\n";
	print FID_H 'in which ' . scalar @complete_files . ' succeeded, and ' . scalar @err_files . ' failed<br>' , "\n";
	
	print FID_H '<br>A tree is provided to demonstrate the process of the data and the relations of the tasks:',"\n";
	print FID_H '<br><a href=results/tree.html>PML data process tree</a>',"\n";
	
	open(FID_tree,">$main::prog_dir/results/$main::name/results/tree" . '.html');
	print FID_tree '<html>',"\n",'<head>',"\n",'<title>',"PML Data Process Tree",'</title>',"\n";
	print FID_tree '<script type="text/javascript" src="../dtree.js"></script>',"\n";#src of tree
	print FID_tree '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
	print FID_tree '<body>',"\n";
	print FID_tree '<a><img src = "./logo.gif" ></a><br>',"\n";
	print FID_tree '<a href=../results.html>Back to home page</a><br>',"\n";
	print FID_tree 'The relations of all the tasks:<br>',"\n";
	print FID_tree '<div class="dtree">',"\n";
	print FID_tree '<p>[<a href="javascript: d.openAll();">open all</a>] | [<a href="javascript: d.closeAll();">close all</a>]</p>',"\n";
	print FID_tree '<script type="text/javascript">',"\n";
	print FID_tree 'd = new dTree(\'d\');',"\n";
	
	my %hash_n_n = map{$hash_n{$_},$_}keys(%hash_n);
	
	print FID_tree 'd.add(0,-1,\'task processes\',"","blue");',"\n";
	for $i(1..$#{[keys %hash_n]}+1){
		my $node_name =  $hash_n_n{$i};
		my ($node_name_out,$nod_type) = replace_out_name($node_name,1);
		my $color = 'blue', my $href = './' . $node_name . '.html';
		$color = 'red' if $hash_isok{$node_name} == 0;
		my $parent_node = $hash_p{$node_name};
		print FID_tree 'd.add(',$i,',',$parent_node,',\'',$node_name_out,' \',"',$href,'","',$color,'","',$nod_type,'");',"\n";
	}
	print FID_tree 'document.write(d);',"\n",'</script>',"\n";
	print FID_tree '<p>[<a href="javascript: d.openAll();">open all</a>] | [<a href="javascript: d.closeAll();">close all</a>]</p>',"\n";
	print FID_tree '</div>',"\n";
	print FID_tree '<a href=../results.html>Back to home page</a>',"\n";
	print FID_tree '</body></html>',"\n";
	close FID_tree;
	
	#Sortable table
	print FID_H '<h2>More details of the evaluation criteria</h2>',"\n";
	print FID_H '<p>A sortable table is provided to record the detailes of each modeling task:<br>',"\n";
	print FID_H 'The PML modeling results table in <a href = ./results/acc_all.html><U>HTML</U></a> and <a href = ./results/acc_all.txt><U>TEXT</U></a> format</p>',"\n";
		
	#Parameter optimization
	if(@main::tt_arg_grid){
		print FID_H '<h2>Parameter Optimization</h2>',"\n";
		print FID_H '<p>This experiment has some modeling methods with changed parameter(s) and the details could be found in the ' .
		'<a href=' . "./results/tree" . '.html>' . '<U>tree</U></a>.<br> '."\n";
		print FID_H 'In addition, different parameters might show discrepant performances due to the criterion.<br>',"\n";
		print FID_H 'Thus, the tables, which conatin the outputs with the best performances under different criterion, are provided:<br>',"\n";
		
		print FID_H '<table id="tss" border="2" cellpadding="5">',"\n";
		print FID_H '<tbody>',"\n";
		my @criterion_names;
		@criterion_names = @acc_names_with_overall;
		@criterion_names = @acc_names_r if $main::regress;
		shift @criterion_names;
		map{	
			print FID_H '<tr>',"\n";
			print FID_H '<td align="right">' . $_ . '</td>',"\n";
			print FID_H '<td align="right"><a href=./results/ParameterOptimization_' . $_ . '.html>' .  'HTML</a></td>',"\n";
			print FID_H '<td align="right"><a href=./results/ParameterOptimization_' . $_ . '.txt>' .  'TEXT</a></td>',"\n";
			print FID_H '</tr>',"\n";
		}@criterion_names;
		print FID_H '</tbody></table>',"\n";
		
	}
	
	#Independent test
	if($main::independent_data){
		print FID_H '<h2>Independent Tests</h2>',"\n";
		print FID_H '<p>The results of the independent tests are combined into a table:<br>',"\n";
		print FID_H 'The Independent test results table in <a href = ./results/independent_all.html><U>HTML</U></a> and <a href = ./results/independent_all.txt><U>TEXT</U></a> format</p>',"\n";
	}
	
	print FID_H '<h2>Best Methods</h2>',"\n";
	print FID_H 'The best method(s) of each evaluation criterion of modeling results is:<br>',"\n";
	#best_acc
	map{$_ =~ s/_nfold$//}@{$best_accs[1]};	
	map{
		my @names = split /\<br\>/,$_;
		map{
			$_ =~ s/_nfold$//;
			$_ = '<a href = "results/' . $_ . '_nfold.html" >' . replace_out_name($_) . '</a>'
		}@names;
		#$_ = '<a href = "results/' . $_ . '_nfold.html" >' . replace_out_name($_) . '</a>'
		$_ = join '<br>',@names;
	}@{$best_accs[1]};
	print FID_H join "\n",print_matrix_trans(@best_accs);
	print FID_H "\n";
	#print FID_H '<br>',"\n";
	print FID_H 'The \'_O\' means the \'Overall\' description.<br>',"\n" if !$main::regress;
	print FID_H 'For more details of these evaluation criteria, please click <a href = ./results/para_explanation.html><U>here</U></a>.';
	
	print FID_H '</body>',"\n",'</html>';
	close FID_H;
	print "Complete\nResults are generated and can be view by browser at " . getcwd() . "/pml/results/$main::name/results.html\n"
}

#*******************************************************************
#
# Function Name: get_nf_name($node_name)
#
# Description: 
#		Get the name of the node of n-fold validation from the name of mdeling node
#
# Parameters:
#
# 		$node_name: The name of modeling node
#		
# Return:
#
#		None
#
#*********************************************************************

sub get_nf_name{
	#Get the name of the node of n-fold validation from the name of mdeling node
	my $file = $_[0];
	$file =~ s/^$main::name//s;
	$file =~ s/^_//;
	my @elements = split /_/,$file;
	my @element_t = grep{/^[cft]/}@elements;
	@element_t = grep{$elements[$_] eq $element_t[$#element_t]}0 .. $#elements;
	@elements = splice(@elements,0,$element_t[$#element_t] + 2);
	my $nf_name = join '_',($main::name,@elements);
	$nf_name .= '_nfold';
	return $nf_name;
}

#*******************************************************************
#
# Function Name: get_nf_name($node_name)
#
# Description: 
#		Get the name of the parent node from the input node name
#
# Parameters:
#
# 		$node_name: The name of modeling node
#		
# Return:
#
#		None
#
#*********************************************************************

sub get_parent_name{
	#Get the name of the parent node from the input node name
	my $file = $_[0];
	$file =~ s/^$main::name//s;
	$file =~ s/^_//;
	my @elements = split /_/,$file;
	#shift @elements;
	if (grep{$_ eq 'inner'}@elements){
		my @element_t = grep{/^inner/}@elements;
		@element_t = grep{$elements[$_] eq $element_t[$#element_t]}0 .. $#elements;
		splice(@elements,$element_t[$#element_t],2);
		my $p_name = join '_',($main::name,@elements);
		return $p_name;
	}
	my @element_t = grep{/^[cft]/}@elements;
	@element_t = grep{$elements[$_] eq $element_t[$#element_t]}0 .. $#elements;
	@elements = @elements[0 .. $element_t[$#element_t] - 1];
	my $p_name = join '_',($main::name,@elements);
	return $p_name;
}

#*******************************************************************
#
# Function Name: get_relate_file($task_name , \%is_complete )
#
# Description: 
#		Analysis the output of the task, generate html file to record the related information.
#
# Parameters:
#
# 		$task_name: The name of the task
#		%is_complete: A hash tables records the whether task was completed or failed
#		
# Return:
#
#		None
#
#*********************************************************************

sub get_relate_file{
	#Analyze the output of the task; generate html file to record the related information.
	
	our @acc_names_r;
	my ($file,$hash_isok_l) = @_;
	@_ = (); #avoid leaking
	my $step = pop @{[grep{/^[cft]/}split /_/,$file]};
	my $is_all;
	$is_all = 1 if $file =~ /all$/;
	open(FID_H,">$main::prog_dir/results/$main::name/results/$file" . '.html');
	
	print FID_H '<!DOCTYPE html>',"\n";
	print FID_H '<html>',"\n",'<head>',"\n",'<title>',join('_',replace_out_name($file,2)),'</title>',"\n";
	print FID_H '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
	print FID_H '<body>',"\n";
	
	#LOGO
	print FID_H '<a><img src = "logo.gif" ></a>',"\n";
	my $isweka; my @prop_details;
	
	print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
	print FID_H '<a href=',get_nf_name($file),'.html><U>View the analysis Cross Validation where this task is located</U></a><br>',"\n" if $step eq 'tt';
	
	#some outputs for errors
	if ($$hash_isok_l{$file} == 0){		
		print FID_H '<br>This task is failed<br>',"\n";
		print FID_H 'It might beacuse the script or the algorithm is not fit for this data<br>',"\n";
		print FID_H '<p><table id = "tss" border = 2 cellpadding=5>',"\n";
		@prop_details = get_script_detail($file);
		$isweka = 1 if grep{$_=~ /weka/}@prop_details;
		print FID_H @prop_details;
		if ($step eq 'tt'){
			my @tt_names = get_tt_name($file);
			my @tt_names_arff = @tt_names;
			map{$_ =~ s/info$/arff/}@tt_names_arff;
			print FID_H '<tr><td>Train data file</td>  <td><a href="',"../data/$tt_names_arff[0]",'">';
			print FID_H $tt_names_arff[0],'</a></td></tr>',"\n";
			print FID_H '<tr><td>Test data file</td> <td><a href="',"../data/$tt_names_arff[1]",'">';
			print FID_H $tt_names_arff[1],'</a></td></tr>',"\n";
			
		}
		else{
			print FID_H '<tr><td>Input data file</td> <td><a href="',"../data/",get_parent_name($file),'.arff">';
			print FID_H get_parent_name($file),'.arff</a></td></tr>',"\n";
		}
		print FID_H '<tr><td>Script file( or compressed file)</td> <td> <a href="',"../err/scripts/$file",'">';
		print FID_H $file,'</a></td></tr>',"\n";
		print FID_H '<tr><td>Jop property file</td> <td> <a href="',"../stepprops/$file",'">';
		print FID_H $file,'</a></td></tr>',"\n";
		
		print FID_H '</table></p>',"\n";
		
		print FID_H retry_detail($step , $isweka);
		print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
		
		print FID_H '</body>',"\n",'</html>';
		close FID_H;
		return;
	}
	if ($step eq 'tt'){
		my @out = read_out_file($file);
		if ($main::regress){
			@out = cal_acc_r(@out);
		}
		else{
			@out = cal_acc_c(@out);
		}
		print FID_H '<h2>Modeling</h2>',"\n";
		print FID_H 'This task is to model data.<br>',"\n";
		print FID_H '<p><table id = "tss" border = 2 cellpadding=5>',"\n";
		@prop_details = get_script_detail($file);
		$isweka = 1 if grep{$_=~ /weka/}@prop_details;
		print FID_H @prop_details;
		
		print FID_H '<tr><td>Script file( or compressed file)</td> <td><a href="',"../complete/scripts/$file",'">';
		print FID_H $file,'</a></td></tr>',"\n";	
		print FID_H '<tr><td>Jop property file</td> <td> <a href="',"../stepprops/$file",'">';
		print FID_H $file,'</a></td></tr>',"\n";
		my @tt_names = get_tt_name($file);
		my @tt_names_arff = @tt_names;
		map{$_ =~ s/info$/arff/}@tt_names_arff;
		print FID_H '<tr><td>Train data file</td>  <td><a href="',"../data/$tt_names_arff[0]",'">';
		print FID_H $tt_names_arff[0],'</a></td></tr>',"\n";
		open(FID_T,"$main::prog_dir/results/$main::name/data/$tt_names[0]");
		while (my $line = <FID_T>){
			if ($line =~ /number of instance is (\d+)/){
				print FID_H '<tr><td>Train data instances</td> <td>',"$1",'</td> </tr>',"\n";
			}
			elsif ($line =~ /number of attribute is (\d+)/){
				print FID_H '<tr><td>Train data attributes</td> <td>',"$1",'</td> </tr>',"\n";
			}
		}close FID_T;
		print FID_H '<tr><td>Test data file</td> <td><a href="',"../data/$tt_names_arff[1]",'">';
		print FID_H $tt_names_arff[1],'</a></td></tr>',"\n";
		open(FID_T,"$main::prog_dir/results/$main::name/data/$tt_names[1]");
		while (my $line = <FID_T>){
			if ($line =~ /number of instance is (\d+)/){
				print FID_H '<tr><td>Test data instances</td> <td>',"$1",'</td></tr>',"\n";
			}
			elsif ($line =~ /number of attribute is (\d+)/){
				print FID_H '<tr><td>Test data attributes</td> <td>',"$1",'</td></tr>',"\n";
			}
		}close FID_T;	
		print FID_H '</table></p>',"\n";
		
		if ($main::regress){
			print FID_H "\n",'Output analysis:<br>',"\n";
			print FID_H join "\n",print_matrix([@acc_names_r],['regress',@out]);
			print FID_H "\n";
			print FID_H '</p>',"\n";
		}
		else{
			print FID_H '<p>',"\n",'Confusion matrix:<br>',"\n";
			print FID_H join "\n",print_conf(@out[1,2]);
			print FID_H '</p>',"\n";
			print FID_H "\n",'<p>',"\n",'Output analysis:<br>',"\n";
			print FID_H join "\n",print_acc($out[0]);
			print FID_H '</p>',"\n";
		}
		
		print FID_H '<a href=',get_nf_name($file),'.html><U>View the analysis Cross Validation where this task is located</U></a><br>',"\n";
	}
	else{
		if ($step eq 'clu'){
			print FID_H '<h2>Cluster</h2>',"\n";
			print FID_H 'This task is to cluster the data.<br>',"\n" if !$is_all;
			print FID_H 'This task is skipped beacuse no instance need to be reduced.<br>',"\n" if $is_all;
			print FID_H 'Only the data for next step is generated:<br>',"\n" if $is_all;
		}else{
			print FID_H '<h2>Variable Selection</h2>',"\n";
			print FID_H 'This task is to select the variables (features).<br>',"\n" if !$is_all;
			print FID_H 'This task is skipped beacuse no attribute need to be reduced.<br>',"\n" if $is_all;
			print FID_H 'Only the data for next step is generated:<br>',"\n" if $is_all;
		}
		
		print FID_H '<p>',"\n",'<table id = "tss" border = 2 cellpadding=5>',"\n";
		@prop_details = get_script_detail($file) if !$is_all;
		$isweka = 1 if !$is_all && grep{$_=~ /weka/}@prop_details;
		print FID_H @prop_details if !$is_all;
		print FID_H '<tr><td>Script file( or compressed file)</td> <td><a href="',"../complete/scripts/$file",'">' if !$is_all;
		print FID_H $file,'</a></td></tr>',"\n" if !$is_all;
		print FID_H '<tr><td>Jop property file</td> <td> <a href="',"../stepprops/$file",'">' if !$is_all;
		print FID_H $file,'</a></td></tr>',"\n" if !$is_all;
		
		print FID_H '<tr><td>Input data file</td> <td><a href="',"../data/",get_parent_name($file),'.arff">';
		print FID_H get_parent_name($file),'.arff</a></td></tr>',"\n";

		my $inst_num, my $att_num;
		print get_parent_name($file),"\n" if !-e "$main::prog_dir/results/$main::name/data/".get_parent_name($file).'.info';
		open(FID_O,"$main::prog_dir/results/$main::name/data/".get_parent_name($file).'.info');
		while (my $line = <FID_O>){
			if ($line =~ /number of instance is (\d+)/){
				$inst_num = $1;
				print FID_H '<tr><td>Input data instances</td> <td>',"$inst_num",'</td></tr>',"\n";
			}
			elsif ($line =~ /number of attribute is (\d+)/){
				$att_num = $1;
				print FID_H '<tr><td>Input data attributes</td><td>',"$att_num",'</td></tr>',"\n";
			}
		}close FID_O;

		print FID_H '<tr><td>Output data file</td> <td><a href="',"../data/$file",'.arff">';
		print FID_H $file,'.arff</a></td></tr>',"\n";
		
		open(FID_O,"$main::prog_dir/results/$main::name/data/$file".'.info');
		while (my $line = <FID_O>){
			if ($line =~ /number of instance is (\d+)/){
				print FID_H '<tr><td>Output data instances</td> <td>',"$1",'</td></tr>',"\n";
				$inst_num -= $1;
			}
			elsif ($line =~ /number of attribute is (\d+)/){
				print FID_H '<tr><td>Output data attributes</td> <td>',"$1",'</td></tr>',"\n";
				$att_num -= $1;
			}
		}close FID_O;
		print FID_H '<tr><td>Recuded instances</td><td>',"$inst_num",'</td></tr>',"\n" if $step eq 'clu' && $inst_num >= 0;
		print FID_H '<tr><td>Recuded attributes</td><td>',"$att_num",'</td></tr>',"\n" if $step eq 'fea' && $att_num >= 0;
		print FID_H '</table></p>';
	}
	
	print FID_H retry_detail($step , $isweka) if !$is_all;
	print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
	print FID_H '</body>',"\n",'</html>';
	close FID_H;
}


#*******************************************************************
#
# Function Name: print_matrix(@accs)
#
# Description: 
#		Format the matrix into HTML format
#
# Parameters:
#
# 		@accs: The matrix (2-dimention ARRAY) with values of the evaluation criterions
#		
# Return:
#
#		The formatted ARRAY.
#
#*********************************************************************

sub print_matrix{
	#Format the matrix into HTML format
	my @matrix = @_;
	my @out, my $i, my $j, my $line;
	push(@out,'<table id="tss" border=2 cellpadding=5>');
	if (@{$matrix[0]}){
		for $i(0..$#matrix){
			push(@out,'<tr>');
			for $j (0..$#{$matrix[0]}){
				$line = '<td align= "right">' . $matrix[$i][$j] . '</td>';
				push(@out,$line);
			}
			push(@out,'</tr>');
		}
	}
	else{
		push(@out,'<tr>');
			for $i(0..$#matrix){
			$line = '    <td align= "right">' . $matrix[$i] . '</td>';
			push(@out,$line);}
		push(@out,'</tr>');
	}
	push @out,'</table>';
	return @out;
}

#*******************************************************************
#
# Function Name: print_matrix_trans(@accs)
#
# Description: 
#		Format the transpose of the matrix into HTML format
#
# Parameters:
#
# 		@accs: The matrix (2-dimention ARRAY) with values of the evaluation criterions
#		
# Return:
#
#		The formatted ARRAY.
#
#*********************************************************************

sub print_matrix_trans{
	#Format the transpose of the matrix into HTML format
	my @matrix = @_;
	my @out, my $i, my $j, my $line;
	push(@out,'<table id="tss" border=2 cellpadding=5>');
	if (@{$matrix[0]}){
		for $i(0..$#{$matrix[0]}){
			push(@out,'<tr>');
			for $j (0..$#matrix){
				$line = '<td align= "right">' . $matrix[$j][$i] . '</td>';
				push(@out,$line);
			}
			push(@out,'</tr>');
		}
	}
	else{
			for $i(0..$#matrix){
				push(@out,'<tr>');
				$line = '    <td align= "right">' . $matrix[$i] . '</td>';
				push(@out,$line);
				push(@out,'</tr>');
			}
	}
	push @out,'</table>';
	return @out;
}

#*******************************************************************
#
# Function Name: print_conf(@confu_matrix)
#
# Description: 
#
#		Format the confusion matrix into HTML format
#
# Parameters:
#
# 		@confu_matrix: The confusion matrix
#		
# Return:
#
#		The formatted ARRAY.
#
#*********************************************************************

sub print_conf{
	#Format the confusion matrix into HTML format
	
	my @confu_matrix = @{$_[0]};
	my @labels = @{$_[1]};
	my @out, my $i, my $j, my $line;
	my @elements = ('a'..'z');
	push(@out,'<table border=0 cellpadding=5>');
	push(@out,'<tr>');
	for $i(0..$#labels){
		$line = '    <td align= "right">' . $elements[$i] . '</td>';
		push(@out,$line);
	}
	push(@out,'    <td align= "right"> </td>');
	push(@out,'    <td ><--classified as</td>');
	push(@out,'</tr>');
	for $i(0..$#confu_matrix){
		push(@out,'<tr>');
		for $j(0..$#{$confu_matrix[0]}){
			$line = '    <td align= "right">' . round($confu_matrix[$i][$j] , 0) . '</td>';
			push(@out,$line);
		}
		push(@out,'    <td align= "right">|</td>');
		push(@out,'    <td >' . $elements[$i] . '=' . $labels[$i] . '</td>');
		push(@out,'</tr>');
	}
	push(@out,'</table>');
	return @out;
}

#*******************************************************************
#
# Function Name: round($in , $d)
#
# Description: 
#
#		Remain specified number decimal places, and the number
#		of the last decimal place would be rounded
#
# Parameters:
#
# 		$in: The input number
#		$d: The number of decimal places to remain
#		
# Return:
#
#		The modified number
#
#*********************************************************************

sub round{
	#Remain specified number decimal places, and the number of the last decimal place would be rounded.
	my ($in , $d) = @_;
	my $out;
	if ($in > 0){
		#$out = int($in * 10 ** $d + 0.5) / 10 ** $d;
		$out = $in * 10 ** $d + 0.5;
		$out = int($out);
		$out = int($out) + 1 if abs($out - int($out) - 1) < 10**-7 ;
		$out = $out / 10 ** $d; 
	}
	else{
		#$out = int($in * 10 ** $d - 0.5) / 10 ** $d;
		$out = $in * 10 ** $d - 0.5;
		$out = int($out);
		$out = int($out) - 1 if abs($out - int($out) + 1) < 10**-7 ;
		$out = $out / 10 ** $d;	
	}
	
	#special situations, like that let 0.71 output as 0.7100
	if ($out == int $out && $d){
		$out .= '.';
		$out .= '0' x $d;
	}
	elsif($d > 1 && $out !~ /\.\d{$d,$d}/s){
		#$out .= '0' if $out * 10 ** ($d - 1) == int($out * 10 ** ($d - 1));
		 $out .= '0' x $d;
		 $out =~ /(-?\d+\.\d{$d,$d})/s;
		 $out = $1;
	}
	
	return $out;
}

#*******************************************************************
#
# Function Name: print_acc(@acc)
#
# Description: 
#
#		Format the matrix into HTML format
#
# Parameters:
#
# 		@acc: The matrix (2-dimention ARRAY) with values of the evaluation criterions
#		
# Return:
#
#		The formatted ARRAY
#
#*********************************************************************

sub print_acc{
	#Format the matrix into HTML format
	my @out_accs = @{$_[0]};
	my $is_overall = $_[1];
	my @out, my $i, my $j, my $line;
	our @acc_names;
	our @acc_names_r;
	our @acc_names_with_overall;
	if ($main::regress && $is_overall){
		push(@out,'<table id="tb" cellpadding=5>');
	}
	else{
		push(@out,'<table id="tss" border=2 cellpadding=5>') if !$is_overall;
		push(@out,'<table id="tb" cellpadding=5>') if $is_overall;
	}
	push(@out,'<thead>') if $is_overall || ($main::regress && $is_overall);
	push(@out,'<tr>');
	if ($is_overall && !$main::regress){
		for $i(0...$#acc_names_with_overall){
			$line = '    <th align= "right">' . $acc_names_with_overall[$i] . '</th>' ;
			push(@out,$line);
		}
	}
	elsif(!$is_overall && $main::regress){
		for $i(0...$#acc_names_r){
			$line = '    <td align= "right">' . $acc_names_r[$i] . '</td>';
			push(@out,$line);
		}
	}
	elsif($is_overall && $main::regress){
		for $i(0...$#acc_names_r){
			$line = '    <th align= "right">' . $acc_names_r[$i] . '</th>';
			push(@out,$line);
		}
	}
	else{
		for $i(0...$#acc_names){
			$line = '    <td align= "right">' . $acc_names[$i] . '</td>';
			push(@out,$line);
		}
	}
	push(@out,'</tr>');
	push(@out,'</thead>') if $is_overall || ($main::regress && $is_overall);
	push(@out,'<tbody>') if $is_overall;
	for $i(0..$#out_accs){
		push(@out,'<tr>');
		$line = '    <td align= "right">' . $out_accs[$i][0] . '</td>';
		push(@out,$line);
		for $j(1..$#{$out_accs[0]}){
			$line = '    <td align= "right">' . round($out_accs[$i][$j],$main::round_l) . '</td>';
			push(@out,$line);
		}
		push(@out,'</tr>');
	}
	push(@out,'</tbody>') if $is_overall;
	push(@out,'</table>');
	return @out;
}

#*******************************************************************
#
# Function Name: print_acc_all_head($isoverall)
#
# Description: 
#
#		Generate the file acc_all.html with some configurations
#		The table contained in this file is designed to record 
#		all the tasks¡¯ evaluation criterions
#
# Parameters:
#
# 		$isoverall: Whether to initialize this table with overall analysis
#		
# Return:
#
#		None
#
#*********************************************************************

sub print_acc_all_head{
	my $is_overall = $_[0];
	my @out, my $i, my $j, my $line;
	our @acc_names;
	our @acc_names_r;
	our @acc_names_with_overall;
	if ($main::regress){
		push(@out,'<table id="tb" cellpadding=5>');
	}
	else{
		push(@out,'<table id="tss" border=2 cellpadding=5>') if !$is_overall;
		push(@out,'<table id="tb" cellpadding=5>') if $is_overall;
	}
	push(@out,'<thead>');
	push(@out,'<tr>');
	if ($main::regress){
		for $i(0...$#acc_names_r){
			$line = '    <th align= "right">' . $acc_names_r[$i] . '</th>';
			push(@out,$line);
		}
	}
	elsif ($is_overall){
		for $i(0...$#acc_names_with_overall){
			$line = '    <th align= "right">' . $acc_names_with_overall[$i] . '</th>' ;
			push(@out,$line);
		}
	}else{
		for $i(0...$#acc_names){
			$line = '    <td align= "right">' . $acc_names[$i] . '</td>';
			push(@out,$line);
		}
	}
	push(@out,'</tr>');
	push(@out,'</thead>');
	return @out;
}

#*******************************************************************
#
# Function Name: print_acc_all_body(@accs , $isoverall)
#
# Description: 
#
#		Add the specified matrix into the sortable table.
#		This table is designed to record all the tasks¡¯ evaluation criterions. 
#
# Parameters:
#
# 		@accs: The matrix (2-dimention ARRAY) with values of the evaluation criterions.
#		$isoverall: Whether the @accs is for overall analysis
#		
# Return:
#
#		None
#
#*********************************************************************

sub print_acc_all_body{
	my @out_accs = @{$_[0]};
	my $is_overall = $_[1];
	my @out, my $i, my $j, my $line;
	our @acc_names;
	our @acc_names_with_overall;	
	for $i(0..$#out_accs){
		push(@out,'<tr>');
		$line = '    <td align= "right">' . $out_accs[$i][0] . '</td>';
		push(@out,$line);
		for $j(1..$#{$out_accs[0]}){
			$line = '    <td align= "right">' . round($out_accs[$i][$j],$main::round_l) . '</td>';
			push(@out,$line);
		}
		push(@out,'</tr>');
	}
	#push(@out,'</table>');
	return @out;
}

#*******************************************************************
#
# Function Name: print_acc_all_body_text(@accs , $isoverall)
#
# Description: 
#
#		Add the specified matrix into a text file.
#		This table is designed to record all the tasks¡¯ evaluation criterions. 
#
# Parameters:
#
# 		@accs: The matrix (2-dimention ARRAY) with values of the evaluation criterions.
#		$isoverall: Whether the @accs is for overall analysis
#		
# Return:
#
#		None
#
#*********************************************************************

sub print_acc_all_body_text{
	my @out_accs = @{$_[0]};
	my $is_overall = $_[1];
	my @out, my $i, my $j, my $line;
	our @acc_names;
	our @acc_names_with_overall;	
	for $i(0..$#out_accs){
		
		#$line = $out_accs[$i][0] . ' ';
		#push(@out,$line);
		for $j(1..$#{$out_accs[0]}){
			$line =  round($out_accs[$i][$j],$main::round_l) . "\t";
			push(@out,$line);
		}
		$line =  'complete/results/' . $out_accs[$i][0] . "\n";
		push(@out,$line);
		#push(@out,"\n");
	}
	#push(@out,'</table>');
	return @out;
}

#*******************************************************************
#
# Function Name: get_tt_name($task_name)
#
# Description: 
#
#		Get the related names of the files which contain 
#		the information of training/test data
#
# Parameters:
#
# 		$task_name: The name of the task
#		
# Return:
#
#		The two names of training data information file and test data information file
#
#*********************************************************************

sub get_tt_name{
	#Get the related names of the files which contain the information of training/test data.
	#example
	#****_tt_*_****
	#del tt_*_ then add _train.info/_test.info
	my $name = $_[0];
	$name =~ s/^$main::name//s;
	$name =~ s/^_//;
	my @elements = split /_/,$name;
	my @element_t = grep{/^[cft]/}@elements;
	@element_t = grep{$elements[$_] eq $element_t[$#element_t]}0 .. $#elements;
	splice(@elements,$element_t[$#element_t],2);
	my $p_name = join '_',($main::name,@elements);
	my $train_name = $p_name . '_train.info';
	my $test_name = $p_name . '_test.info';
	return ($train_name,$test_name);
}

#*******************************************************************
#
# Function Name: analysis_nfold(\%is_complete , \%nodes ,
#			 \%parents , \%nfold_nodes)
#
# Description: 
#
#		Generate the analysis of n-fold cross validation based on
#		the output files of function get_relate_file
#
# Parameters:
#
# 		%is_complete: A hash tables records the whether task was completed or failed
#		%nodes: A hash tables records the serial of tasks in the output tree
#		%parents: A hash tables records the parent nodes of each nodes.
#		%nfold_nodes: A hash tables records the node of nfold.
#		
# Return:
#
#		A matrix (2-dimension ARRAY) contain the best methods with 
#		the best evaluation criterions values
#
#*********************************************************************

sub analysis_nfold{
	#Generate the analysis of n-fold cross validation based on the output files of function get_relate_file
	
	my ($hash_isok_l,$hash_n_l,$hash_p_l,$hash_nfold_l) = @_;
	my @nf_names = keys(%$hash_nfold_l);
	my @best_accs :shared; our @acc_names, our @acc_names_r;
	my (@b1,@b2,@b3) :shared;
	@best_accs = (\@b1,\@b2,\@b3);
	init_best_accs(\@best_accs,!$main::regress);
	my $complete_jobs = 0;
	my $total_jobs = scalar @nf_names;
	
	#Out table for independent test tasks
	my ($indep_file_handle, $indep_text_file_handle);
	if($main::independent_data){
		open($indep_file_handle,">$main::prog_dir/results/$main::name/results/independent_all.html");
		#head
		print $indep_file_handle '<!DOCTYPE html>',"\n";
		print $indep_file_handle '<html>',"\n",'<head>',"\n",'<title>','All of the details of independent tests','</title>',"\n";
		print $indep_file_handle '<script type="text/javascript" src="../tableSort.js"></script>',"\n";#src of the sort table
		print $indep_file_handle '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
		print $indep_file_handle '<body>',"\n";
		#LOGO
		print $indep_file_handle '<a><img src = "logo.gif" ></a>',"\n";
		print $indep_file_handle '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
		print $indep_file_handle '<h2>Independent Test Results</h2>',"\n";
		print $indep_file_handle 'All of the independent test results:<br>',"\n";
		print $indep_file_handle 'Click the table headers to sort the results by that colunm<br>',"\n";
		print $indep_file_handle '<table id="tb" cellpadding=5>',"\n",'<thead>',"\n","<tr>";
		
		my @sub_names;
		@sub_names = @acc_names;
		@sub_names = @acc_names_r if $main::regress;
		for my $i(0...$#sub_names){
			my $line = '    <th align= "right">' . $sub_names[$i] . '</th>';
			print $indep_file_handle $line,"\n";
		}		
		print $indep_file_handle '</tr>',"\n";
		print $indep_file_handle '</thead>',"\n";
		
		print $indep_file_handle '<tbody>',"\n";
		
		#text file
		open($indep_text_file_handle,">$main::prog_dir/results/$main::name/results/independent_all.txt");
#		my @sub_names = @acc_names;
#		@sub_names = @acc_names_r if $main::regress;
		shift @sub_names;
		print $indep_text_file_handle join "\t",(@sub_names,"Out_file_position\n");
	}
	
	#parallel parameters
	my (%hash_id_time , %hash_id_name , %hash_name_repeat);
	
	while ($#nf_names >= 0 || scalar(threads->list()) > 0){
		while (scalar(threads->list()) < $main::core_number && $#nf_names >= 0){
			my $thread = threads->create(
			sub{
				my ($nf_name) = @_;
				@_ = (); #avoid leaking
				
				open(FID_H,">$main::prog_dir/results/$main::name/results/$nf_name" . '.html');
				#head
				print FID_H '<!DOCTYPE html>',"\n";
				print FID_H '<html>',"\n",'<head>',"\n",'<title>',join('_',replace_out_name($nf_name,2)),'</title>',"\n";
				print FID_H '<script type="text/javascript" src="../dtree.js"></script>';
				print FID_H '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
				print FID_H '<body>',"\n";
				
				#LOGO
				print FID_H '<a><img src = "logo.gif" ></a>',"\n";
				
				print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
				print FID_H '<p><a href=',get_gd_name($nf_name),'.html><U>View the parameter optimization results where this statistics are located</U></a></p>',"\n";
				print FID_H '<h2>Cross Validation</h2>',"\n";
				
				#Get the nodes to make the tree
				my @sub_nodes = grep{$$hash_p_l{$_} eq $$hash_n_l{$nf_name}}keys(%$hash_p_l);
				my @independent_nodes = grep{	$_ =~ /independent$/	}@sub_nodes;
				@sub_nodes = grep{	$_ !~ /independent$/	}@sub_nodes;
				#n-fold tree
				print FID_H 'The tasks in n-fold cross validation:<br>',"\n";
				print FID_H '<div class="dtree">',"\n";
				print FID_H '<p>[<a href="javascript: d.openAll();">open all</a>] | [<a href="javascript: d.closeAll();">close all</a>]</p>',"\n";
				print FID_H '<script type="text/javascript">',"\n";
				print FID_H 'd = new dTree(\'d\')',"\n";
				print FID_H 'd.add(0,-1,\'Cross Validation\',"","blue")',"\n";
				for(@sub_nodes , @independent_nodes){
					
					my $node_name =  $_;
					my ($node_name_out,$nod_type) = replace_out_name($node_name,1);
					my $color = 'blue', my $href = './' . $node_name . '.html';
					$color = 'red' if $$hash_isok_l{$node_name} == 0;
					my $parent_node = 0;
					print FID_H 'd.add(',$$hash_n_l{$node_name},',',$parent_node,',\'',$node_name_out,' \',"',$href,'","',$color,'","',$nod_type,'");',"\n";
					
					my @sub_inner_nodes = grep{$$hash_p_l{$_} eq $$hash_n_l{$node_name}}keys(%$hash_p_l) if $main::inner_folds;
					next if !@sub_inner_nodes;
					for (@sub_inner_nodes){
						my $node_name =  $_;
						my ($node_name_out,$nod_type) = replace_out_name($node_name,1);
						my $color = 'blue', my $href = './' . $node_name . '.html';
						$color = 'red' if $$hash_isok_l{$node_name} == 0;
						my $parent_node = $$hash_p_l{$node_name};
						print FID_H 'd.add(',$$hash_n_l{$node_name},',',$parent_node,',\'',$node_name_out,' \',"',$href,'","',$color,'","',$nod_type,'");',"\n";
						
					}
				}
				print FID_H 'document.write(d);',"\n";
				print FID_H '</script>',"\n";
				print FID_H '<p>[<a href="javascript: d.openAll();">open all</a>] | [<a href="javascript: d.closeAll();">close all</a>]</p>',"\n";
				print FID_H '</div>',"\n";
				
				print FID_H 'There are some statisitical results of cross validation:',"\n";
				#sub nodes
				
				#parameters of the n-fold through getting one of the parameters of a subnode in the folds
				print FID_H '<p><table id = "tss" border = 2 cellpadding=5>',"\n";
				print FID_H get_script_detail($sub_nodes[0]);
				print FID_H '</table></p>';
				#confirm the useable of each nodes firstly
				if (grep{!$$hash_isok_l{$_}}@sub_nodes){
					$$hash_isok_l{$nf_name} = 0;
					print FID_H 'There are some error tasks in this n-fold compute:<br>',"\n";
					print FID_H join(' ',grep{!$$hash_isok_l{$_}}@sub_nodes);
					print FID_H '<br>',"\n";
					print FID_H '</body>',"\n";
					print FID_H '</html>',"\n";
					close FID_H;
					return;
				}
				$$hash_isok_l{$nf_name} = 1;
				
				my @accs;
				my @confu_matrix_outer;
				for my $file(@sub_nodes){
					my @inner_accs;
					push @accs,[read_html_list("$main::prog_dir/results/$main::name/results/$file")];
					update_confusion_matrix("$main::prog_dir/results/$main::name/results/$file",\@confu_matrix_outer) if !$main::regress;
					#consider the sub nodes of innerfolds
					my @sub_inner_nodes = grep{$$hash_p_l{$_} eq $$hash_n_l{$file}}keys(%$hash_p_l) if $main::inner_folds;
					my @confu_matrix_inner;
					if(@sub_inner_nodes){
						for my $inner_file(@sub_inner_nodes){				
							push @inner_accs,[read_html_list("$main::prog_dir/results/$main::name/results/$inner_file")];
							update_confusion_matrix("$main::prog_dir/results/$main::name/results/$inner_file",\@confu_matrix_inner) if !$main::regress;
						}
						@inner_accs = mean_acc(@inner_accs);
						if (!$main::regress){
							my @overall = get_overall(@confu_matrix_inner);
							map{splice @{$overall[$_]},0,0,"$inner_accs[$_][0]_O"}0..$#overall;
							@overall = mean_acc_overall(@overall);
							push @inner_accs,@overall;
						}
						print FID_H 'The averages from evaluation criteria of inner folds about ';
						$file =~ /(outer)_(\d+)/;
						print FID_H "$1",' fold ',"$2",' are:<br>',"\n";
						print FID_H join "\n",print_acc([@inner_accs]);
						print FID_H '<p>',"\n";
					}
				}
				@accs = mean_acc(@accs);
				if (!$main::regress){
					my @overall = get_overall(@confu_matrix_outer);
					map{splice @{$overall[$_]},0,0,"$accs[$_][0]_O"}0..$#overall;
					@overall = mean_acc_overall(@overall);
					my @accs_overall = @{$accs[$#accs]} ;
					push @accs_overall,@{$overall[$#overall]}[1..$#{$overall[$#overall]}];
					{
						lock @best_accs;
						update_best_acc(\@best_accs,\@accs_overall,$nf_name,!$main::regress);
					}
					push @accs,@overall;
				}
				else{
					my @accs_regress = @{$accs[0]};
					{
						lock @best_accs;
						update_best_acc(\@best_accs,\@accs_regress,$nf_name);
					}
				}
				
				print FID_H "\n",'The evaluation criteria of all the outer folds are:<br>',"\n";
				print FID_H join "\n",print_acc([@accs]);
				print FID_H '<p>',"\n";
				
				if ($main::independent_data){
					#Add the analysis output of the independent test set
					my @accs;
					my $indep_name = $nf_name;
					$indep_name =~ s/_nfold$/_independent/;
							
					#Check wether the independent task is right
					if (grep{!$$hash_isok_l{$_}}@independent_nodes){
						print FID_H "\n",'The related <a href= ' . $indep_name . '.html ><U>independent test task</U></a> is failed,<br>',"\n";
						print FID_H 'It might due to the independent dataset or the dimension reduction methods are not compatible.<br>',"\n";
						print FID_H 'Please check the dataset or use other methods.<br>',"\n";
					}
					else{				
						push @accs,read_html_list("$main::prog_dir/results/$main::name/results/$indep_name");
						#Get the average
	#					my @names;
	#					map{
	#						push @names,shift(@{[$_]});						 
	#					}@accs;
	#					push @names,'Average';
						@accs = mean_acc_overall(@accs);
						$accs[$#accs][0] = 'Average';
						@accs = pop @accs if $main::regress;
						print FID_H "\n",'The evaluation criteria of the related <a href= ' . $indep_name . '.html ><U>independent test dataset</U></a> are:<br>',"\n";
						print FID_H join "\n",print_acc([@accs]);
						print FID_H '<p>',"\n";
						my @average = pop @accs;
						$average[0][0] = $indep_name;
						{
							flock($indep_text_file_handle,2);
							print $indep_text_file_handle join "",print_acc_all_body_text([@average] , 1);
							flock($indep_text_file_handle,8);
						}
						#$accs[$#accs][0] = '<a href='. $indep_name . '.html>' . $indep_name . '</a>';
						
						$average[0][0] = '<a href='. $indep_name . '.html>' . replace_out_name($indep_name) . '</a>';
						{
							flock($indep_file_handle,2);
							print $indep_file_handle join "\n",print_acc_all_body([@average] , 1);
							print $indep_file_handle "\n";
							flock($indep_file_handle,8);
						}
					}
				}
				
				print FID_H '<p><a href=',get_gd_name($nf_name),'.html><U>View the parameter optimization results where this statistics are located</U></a></p>',"\n";
				print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
				print FID_H '</body>',"\n";
				print FID_H '</html>',"\n";
				close FID_H;
			} , $nf_names[0] );
			my $tid = $thread->tid();
			
			$hash_id_name{$tid} = $nf_names[0];
			$hash_id_time{$tid} = time;
			shift @nf_names;
		}
		foreach my $thread(threads->list(threads::all)){
			my $tid = $thread->tid();
			if($thread->is_joinable()){
				delete $hash_id_name{$tid};
				delete $hash_id_time{$tid};
				$thread->join();
				$complete_jobs++;
				show_out_files_progress($complete_jobs,$total_jobs) if !$main::silent;
			}
			else{
				if (time - $hash_id_time{$tid} > $main::time_limit_result){
					push @nf_names,$hash_id_name{$tid};
					$thread->exit();
					$hash_name_repeat{$hash_id_name{$tid}}++;
					die "PML has repeat over 100 times for one result analysis:\n".$hash_id_name{$tid}.
					"\nplease retry PML or check the parameters.\n" if $hash_name_repeat{$hash_id_name{$tid}} > 100;
					delete $hash_id_name{$tid};
					delete $hash_id_time{$tid};
					
				}
			}
		}
	}
	
	if ($main::independent_data){
			print $indep_file_handle '</tbody>',"\n";
			print $indep_file_handle '</table>',"\n";
			
			print $indep_file_handle 'The \'_O\' means the \'Overall\' description.<br>',"\n" if !$main::regress;
			print $indep_file_handle 'For more details of these evaluation criteria, please click <a href = ./para_explanation.html><U>here</U></a>.';
			
			print $indep_file_handle '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
			print $indep_file_handle '</body>',"\n";
			print $indep_file_handle '</html>',"\n";
			close $indep_file_handle;
	}
	
	
	my @out;
	map{
		my $x = $_;
		map{
			$out[$x][$_]=$best_accs[$x][$_];
		}0..$#{$best_accs[$x]}
	}0..$#best_accs;
	return(@out);
}

#*******************************************************************
#
# Function Name: update_confusion_matrix($file , \@confu_matrix)
#
# Description: 
#
#		Update the confusion matrix during the overall analysis.
#
# Parameters:
#
# 		$file: The name of file which is generated by function get_relate_file
#		@confu_matrix: Confusion matrix.
#		
# Return:
#
#		None
#
#*********************************************************************

sub update_confusion_matrix{
	my ($file , $confu_matrix_l) = @_;
	my ($switch , $row , $l , $max_row) = (0,-2,-1,0);#switch,row,cloume,max row
	open(FID,$file . '.html');
	while (my $line = <FID>){
		if ($line =~ /Confusion matrix:/){
			$switch = 1;
		}
		elsif ($line =~ /\<tr\>/ && $switch){
			$row++;
			$switch = 0 if $row > $max_row;
		}
		elsif ($line =~ /\<td align= "right"\>(\d+)\</ && $row >= 0 && $switch){
			$l++;
			$$confu_matrix_l[$row][$l] += $1 if $l >= 0;
			$max_row = $l if $max_row < $l;
		}
		elsif ($line =~ /\<td align= "right"\>|\</ && $row >= 0 && $switch){
			#the | means to deal with the next row
			$l = -1;
		}
	}
	close FID;
}

#*******************************************************************
#
# Function Name: get_overall( @confu_matrix )
#
# Description: 
#
#		Get the overall information for n-fold classify tasks.
#
# Parameters:
#
# 		@confu_matrix: The confusion matrix of the predicted task
#		
# Return:
#
#		The values of the evaluation criterions
#
#*********************************************************************

sub get_overall{
	#Get the overall information for n-fold classify tasks.
	#Overall means combining all the instances of n-fold tasks then analyze them as one predict task.

	my @confu_matrix = @_;
	my @out;
	for my $i (0..$#confu_matrix){
		push @out,[get_overall_single( $i , @confu_matrix)];
	}
	return @out;
}

#*******************************************************************
#
# Function Name: get_overall_single($label_count , @confu_matrix)
#
# Description: 
#
#		Get the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 for 
#		the specified label of overall analysis.
#
# Parameters:
#
# 		@confu_matrix: The confusion matrix of the predicted task
#		$label_count: The serial number of the label which is 
#				used to generated the outputs.
#		
# Return:
#
#		The values of the evaluation criterions
#
#*********************************************************************

sub get_overall_single{
	#Get the TPR, FPR, ACC, SPC, PPV, NPV, FDR, MCC, F1 for the specified label of overall analysis.	
	my ($i , @confu_matrix) = @_;
	my $TP = $confu_matrix[$i][$i];
	my $FP = 0; map{$FP += $confu_matrix[$_][$i]}0 .. $#confu_matrix;
	$FP -= $TP;
	my $FN = 0; map{$FN += $confu_matrix[$i][$_]}0 .. $#confu_matrix;
	$FN -= $TP;
	my $x;
	my $TN = 0;
	
	map{$x = $_;
		[map{$TN += $confu_matrix[$x][$_]}0 .. $#confu_matrix]
	}0 .. $#confu_matrix;
	$TN -= ($TP + $FN + $FP);
	
	my $P = $TP + $FN, my $P1 = $TP + $FP;
	my $N = $FP + $TN, my $N1 = $TN + $FN;
	my $TPR = $TP / $P if $P != 0;	$TPR = -1 if $P == 0;
	my $FPR = $FP / $N if $N != 0;	$FPR = -1 if $N == 0;
	
	my $ACC;
	$ACC = ($TP + $TN) / ($P + $N) if $P + $N != 0;
	$ACC = 0 if $P + $N == 0;
	my $SPC = 1 - $FPR;
	my $PPV = $TP / $P1 if $P1 != 0;	$PPV = -1 if $P1 == 0;
	my $NPV = $TN / $N1 if $N1 != 0;	$NPV = -1 if $N1 == 0;
	my $FDR = $FP / $P1 if $P1 != 0;	$FDR = 1 if $P1 == 0;
	my $MCC = ($TP * $TN - $FP * $FN) / sqrt($P * $N * $P1 * $N1) if $P * $N * $P1 * $N1 != 0;
	$MCC = -1 if $P * $N * $P1 * $N1 == 0;
	my $F1 = 2 * $TP / ($P + $P1) if $P + $P1 != 0;	$F1 = -1 if $P + $P1 == 0; 
	
	return ($TPR , $FPR , $ACC , $SPC , $PPV , $NPV , $FDR , $MCC , $F1);
}

#*******************************************************************
#
# Function Name: read_html_list($task_name)
#
# Description: 
#
#		Read the matrix in the .html file which is generated 
#		by function get_relate_file
#
# Parameters:
#
# 		$task_name: The name the task
#		
# Return:
#
#		The values of the evaluation criterions
#
#*********************************************************************

sub read_html_list{
	#Read the matrix in the .html file which is generated by function get_relate_file
	my $file = $_[0];
	open(FID,$file . '.html');
	my ($switch,$row);
	my @line, my @lines;
	while (my $line = <FID>){
		if ($line =~ /^Output analysis:/){
			$switch = 1;
		}
		elsif ($line =~ /^\<tr\>/ && $switch){
			$row++;
		}
		elsif ($line =~ /\<td align= "right"\>([^\<]+)\</ && $row && $row > 1 && $switch){
			push @line,$1;
		}

		elsif ($line =~ /^\<\/tr\>/ && $switch && $row && $row > 1){
			push @lines,[@line];
			@line = ();
		}
		elsif ($line =~ /\<\/table\>/ && $switch){
			$switch = 0;
		}
	}
	close FID;
	return @lines;
}

#*******************************************************************
#
# Function Name: mean_acc(@accs)
#
# Description: 
#
#		Calculate the mean values of each label with values of the 
#		evaluation criterions in n-fold results. Then get the related 
#		average values for all the labels
#
# Parameters:
#
# 		@accs: The values of the evaluation criterions about specified n-fold results.
#		
# Return:
#
#		A matrix (2-dimention ARRAY) contains the mean evaluation 
#		criterions for labels and the average of them in the last row.
#
#*********************************************************************

sub mean_acc{
	#Calculate the mean values of each label with values of the evaluation criterions in n-fold results.
	#Then get the related average values for all the labels.
	#note that the first element is name
	my @accs = @_;
	my @out;
	if($#{$accs[0][0]} == -1){
		#return if only one fold
		return @accs;
	}
	my ($i,$j,$k);
	for $i(0..$#accs){
		for $j(0..$#{$accs[0]}){
			$out[$j][0] = $accs[$i][$j][0] if $i == 0;
			for $k(1..$#{$accs[0][0]}){
				$out[$j][$k] += $accs[$i][$j][$k] / ($#accs + 1);
			}
		}
	}
	#round the values
	for $i(0..$#out){
		for $j(1..$#{$out[0]}){
			$out[$i][$j] = round($out[$i][$j],$main::round_l);
		}
	}
	if ($main::regress){
		$out[0][0] = 'Average';
		return @out;
	}
	#add the average
	my @avg = ('Average');
	for $j(1..$#{$out[0]}){
		for $i(0..$#out){
			$avg[$j] += $out[$i][$j];
		}
		$avg[$j] /= $#out + 1;
		$avg[$j] = round ($avg[$j],$main::round_l);
	}
	return (@out,[@avg]);
}

#*******************************************************************
#
# Function Name: mean_acc(@overall_accs)
#
# Description: 
#
#		Calculate the average values for all the labels of the overall matrix.
#
# Parameters:
#
# 		@overall_accs: The values of the evaluation criterions about specified overall accs
#		
# Return:
#
#		The @overall_accs add with a row with the average values
#
#*********************************************************************

sub mean_acc_overall{
	#Calculate the average values for all the labels of the overall matrix.
	my @accs = @_;
	my @out;
	if($#accs == -1){
		return @accs;
	}
	my ($i,$j,$k);
	$out[0] = 'Average_O';
	for $j(0..$#accs){
		for $k(1..$#{$accs[0]}){
			$out[$k] += $accs[$j][$k] / ($#accs + 1);
		}
	}
	map{map{$_ = round($_,$main::round_l)}@{$_}[1..$#{$_}]}@accs;
	map{$_ = round($_,$main::round_l)}@out[1..$#out];
	return @accs,[@out];
}

#*******************************************************************
#
# Function Name: get_script_detail($prop_file)
#
# Description: 
#
#		Get the information from the file which was generated 
#		during the process of scripts generations. Then format 
#		the information into HTML format
#
# Parameters:
#
# 		$prop_file: The file contains the information of related task
#		
# Return:
#
#		The formatted information ARRAY.
#
#*********************************************************************

sub get_script_detail{
	my $prop_name = $_[0];
	$prop_name =~ s/_[a-zA-Z\d]+$//;
	if ($prop_name =~ /^(.+_tt_[\d\.]+)/){
		$prop_name = $1;
	}
	open(FID,"$main::prog_dir/results/$main::name/jobprops/$prop_name");
	my @lines = <FID>;
	close FID;
	for my $line (@lines){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ /^(Job proportion) : ([^\n]+)\n/){
			my @line_ele = ($1,$2);
			$line = join '</td><td>',@line_ele;
			$line .= '</td></tr><tr><td>' . "\n"; 
		}
		elsif ($line =~ /Parameters:\n/){
			$line =~ s/:\n$//;
			$line .= '</td><td>' . "\n";
		}
		else {
			$line =~ s/\n$/<br>/;
		}
	}
	return '<tr><td>',@lines,'</td></tr>',"\n";
}

#*******************************************************************
#
# Function Name: get_gd_name($nf_name)
#
# Description: 
#
#		Get the name of the node of parameter optimization 
#		from the name of n-fold validation node
#
# Parameters:
#
# 		$nf_name: The name of n-fold validation node
#		
# Return:
#
#		The name of the node of parameter optimization
#
#*********************************************************************

sub get_gd_name{
	#Get the name of the node of parameter optimization from the name of n-fold validation node
	#example
	#..._tt_x.x_nfold --> ..._tt_x_grid
	#..._tt_x_nfold --> ..._tt_x_grid
	my $nf_name = $_[0];
	$nf_name =~ s/_nfold$//;
	$nf_name =~ s/\.\d+$//;
	return $nf_name . '_grid'; 
}

#*******************************************************************
#
# Function Name: analysis_grid(\%is_complete , \%nodes , 
#				\%parents , \%grid_nodes , \%related_names)
#
# Description: 
#
#		Generate the analysis of n-fold cross validation based on 
#		the output files of function analysis_nfold
#
# Parameters:
#
# 		%is_complete: A hash tables records the whether task was completed or failed
#		%nodes: A hash tables records the serial of tasks in the output tree
#		%parents: A hash tables records the parent nodes of each nodes.
#		%grid_nodes: A hash tables records the node of parameter optimization analysis.
#		
# Return:
#
#		none
#
#*********************************************************************

sub analysis_grid{
		
	my ($hash_isok_l,$hash_n_l,$hash_p_l,$hash_gd_l,$related_names_l) = @_;
	my @gd_names = keys(%$hash_gd_l);
	my $gd_name;
	
	our @acc_names, our @acc_names_r , our @acc_names_with_overall;
		
	#Sortable table
	open(FID_all,">$main::prog_dir/results/$main::name/results/acc_all.html");
	#head
	print FID_all '<!DOCTYPE html>',"\n";
	print FID_all '<html>',"\n",'<head>',"\n",'<title>','All of the details','</title>',"\n";
	print FID_all '<script type="text/javascript" src="../tableSort.js"></script>',"\n";#src of the sort table
	print FID_all '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
	print FID_all '<body>',"\n";
	#LOGO
	print FID_all '<a><img src = "logo.gif" ></a>',"\n";
	print FID_all '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
	print FID_all '<h2>Modeling Results</h2>',"\n";
	print FID_all 'All of the modeling results:<br>',"\n";
	print FID_all 'Click the table headers to sort the results by that colunm<br>',"\n";
	print FID_all join "\n",print_acc_all_head( 1);
	print FID_all "\n";
	print FID_all '<tbody>',"\n";
	
	
	#Generate some subtables if needed
	#File handle of the sortable sub tables
	my @sub_all_handle;
	#File handle of the sortable sub tables with text format 
	my @sub_all_handle_text;
	if (@main::tt_arg_grid){
		my @sub_names;
		@sub_names = @acc_names_with_overall;
		@sub_names = @acc_names_r if $main::regress;
		shift @sub_names;
		my $n = 0;
		map{										
			open $sub_all_handle[$n], ">$main::prog_dir/results/$main::name/results/ParameterOptimization_" . $_ . ".html";
			open $sub_all_handle_text[$n], ">$main::prog_dir/results/$main::name/results/ParameterOptimization_" . $_ . ".txt";
			#Add the headers to the HTML outputs
			modify_sub_tables($sub_all_handle[$n] , $_ , 'head');
			#Add the headers to the Text outputs
			my $head = join "\t",(@sub_names,'Out_file_position'."\n");
			my $file_handle = $sub_all_handle_text[$n];
			print $file_handle $head;
			$n++;
		}@sub_names;
	}
	
	
	#Table of text format
	open(FID_all_text,">$main::prog_dir/results/$main::name/results/acc_all.txt");
	if($main::regress){
		my $text = join("\t",(@acc_names_r[1..$#acc_names_r],"Out_file_position"));
		$text =~ s/^\s+//;
		print FID_all_text $text;
	}
	else{
		my $text = join("\t",(@acc_names_r[1..$#acc_names_r],"Out_file_position"));
		$text =~ s/^\s+//;
		print FID_all_text join("\t",(@acc_names_with_overall[1..$#acc_names_with_overall],"Out_file_position\n"));
	}
	#parallel parameter
	my (%hash_id_time , %hash_id_name , %hash_name_repeat);

	
	my $complete_jobs = 0;
	my $total_jobs = scalar @gd_names;
	while ($#gd_names >= 0 || scalar(threads->list()) > 0){
		while (scalar(threads->list()) < $main::core_number && $#gd_names >= 0){
			my $thread = threads->create(sub{
				my ($gd_name) = @_;
				@_ = (); #avoid leaking
				my @accs, my @acc;
				my @best_accs;
				init_best_accs(\@best_accs,!$main::regress);
				open(FID_H,">$main::prog_dir/results/$main::name/results/$gd_name" . '.html');
				#head
				print FID_H '<!DOCTYPE html>',"\n";
				print FID_H '<html>',"\n",'<head>',"\n",'<title>',join('_',replace_out_name($gd_name,2)),'</title>',"\n";
				print FID_H '<script type="text/javascript" src="../tableSort.js"></script>',"\n";#src of the sort table
				print FID_H '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
				print FID_H '<body>',"\n";
				
				#LOGO
				print FID_H '<a><img src = "logo.gif" ></a>',"\n";
				
				print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
				
				print FID_H '<h2>Parameter Optimization</h2>',"\n";

				#sub nodes
				my @sub_nodes = grep{$$hash_p_l{$_} eq $$hash_n_l{$gd_name}}keys(%$hash_p_l);
				
				print FID_H 'There are some statistical results of a method with different parameters.<br>',"\n";
				#find the average values in the last line of the tables
				for my $file(@sub_nodes){
					@acc = read_html_list_nf($file);
					if ($acc[0] ne 'err'){
						push @accs,[$file,@acc[1..$#acc]];
						update_best_acc(\@best_accs,\@acc,$file,!$main::regress);
					}
				}
				if (@accs){
					
					#Print some infomation to sub tables if needed
					
					if (@main::tt_arg_grid){
						#File handle of the sortable sub tables
						#my @sub_all_handle;
					
						#File handle of the sortable sub tables with text format 
						#my @sub_all_handle_text;
						my @sub_names;
						@sub_names = @acc_names_with_overall;
						@sub_names = @acc_names_r if $main::regress;				
						shift @sub_names;
						my $n = 0;
						for(@sub_names){	
							my $sub_name = $_;
							#Get the best method for the specifted criterion
							my $i = 0;
							for (@{$best_accs[0]}){
								last if $_ eq $sub_name;
								$i++;
							}
							my $sub_method = $best_accs[1][$i];
							my @sub_acc;
							map{
								my $sub_method_name = $_;
								$i = 0;
								for (0..$#accs){
									last if $accs[$_][0] eq $sub_method_name;
									$i++;								
								}
								push @sub_acc,[@{$accs[$i]}];
							}split /\<br\>/,$sub_method;
							#my @sub_acc = @{$accs[$i]};
							
							@sub_acc = shift @sub_acc if $main::one_out_per_opt;
							
							modify_sub_tables($sub_all_handle_text[$n] , $_ , 'body' , 1 , \@sub_acc);
							
							map{$sub_acc[$_][0] =~ s/_nfold$//}0..$#sub_acc;
							map{$sub_acc[$_][0] = '<a href = "' . $sub_acc[$_][0] . '_nfold.html" >' . replace_out_name($sub_acc[$_][0]) . '</a>'}0..$#sub_acc;
							
							modify_sub_tables($sub_all_handle[$n] , $_ , 'body' , 0 , \@sub_acc);
							$n++;
						}
					}
					
					#Print the Text table at first
					{						
						flock(FID_all_text,2);
						my $text_output = join "",print_acc_all_body_text([@accs] , 1);
#						$text_output =~ s/^\s+//;
#						$text_output =~ s/\s+$//;
						print FID_all_text $text_output;
						flock(FID_all_text,8);
					}
					
					map{$accs[$_][0] =~ s/_nfold$//}0..$#accs;
					map{$accs[$_][0] = '<a href = "' . $accs[$_][0] . '_nfold.html" >' . replace_out_name($accs[$_][0]) . '</a>'}0..$#accs;
					$$hash_isok_l{$gd_name} = 1;
					print FID_H '<p>The best method(s) of each evaluation criterion is:<br>',"\n";
					map{$best_accs[1][$_] =~ s/_nfold$//}0..$#{$best_accs[1]};
					map{
						my @names = split /\<br\>/,$best_accs[1][$_];
						map{
							$_ =~ s/_nfold$//;
							$_ = '<a href = "' . $_ . '_nfold.html" >' . replace_out_name($_) . '</a>'
						}@names;
						$best_accs[1][$_] = join '<br>',@names;
					}0..$#{$best_accs[1]};
					#print best accs
					print FID_H join "\n",print_matrix_trans(@best_accs);
					print FID_H "\n";
					print FID_H '</p><p>The detail of successful cross validation statistical outputs are listed as follows:<br>',"\n";
					print FID_H 'Click the table headers to sort the results by that colunm<br>',"\n";
					print FID_H join "\n",print_acc([@accs] , 1);
					print FID_H "\n";
					{
						flock(FID_all,2);
						print FID_all join "\n",print_acc_all_body([@accs] , 1);
						print FID_all "\n";
						flock(FID_all,8);
					}
					print FID_H 'The \'_O\' means the \'Overall\' description.<br>',"\n" if !$main::regress;
					print FID_H 'For more details of these evaluation criteria, please click <a href = ./para_explanation.html><U>here</U></a>.';
				}else{
					print FID_H 'All of the tasks about this method are faild, may be this algorthm is not fit for this data.<br>',"\n";
					$$hash_isok_l{$gd_name} = 0;
				}
				
				
				
				
				print FID_H '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
				print FID_H '</body>',"\n";
				print FID_H '</html>',"\n";
				close FID_H;
			} , $gd_names[0]);
			my $tid = $thread->tid();
			$hash_id_name{$tid} = $gd_names[0];
			$hash_id_time{$tid} = time;
			shift @gd_names;
		}
		foreach my $thread(threads->list(threads::all)){
			my $tid = $thread->tid();
			if($thread->is_joinable()){
				delete $hash_id_name{$tid};
				delete $hash_id_time{$tid};
				$thread->join();
				$complete_jobs++;
				show_out_files_progress($complete_jobs,$total_jobs) if !$main::silent;
			}
			else{
				if (time - $hash_id_time{$tid} > $main::time_limit_result){
					push @gd_names,$hash_id_name{$tid};
					$hash_name_repeat{$hash_id_name{$tid}}++;
					die "PML has repeat over 100 times for one result analysis:\n".$hash_id_name{$tid}.
					"\nplease retry PML or check the parameters.\n" if $hash_name_repeat{$hash_id_name{$tid}} > 100;
					$thread->exit();
					delete $hash_id_name{$tid};
					delete $hash_id_time{$tid};
				}
			}
		}
	}
	print FID_all '</tbody>',"\n";
	print FID_all '</table>',"\n";
	
	print FID_all 'The \'_O\' means the \'Overall\' description.<br>',"\n" if !$main::regress;
	print FID_all 'For more details of these evaluation criteria, please click <a href = ./para_explanation.html><U>here</U></a>.';
	
	print FID_all '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
	print FID_all '</body>',"\n";
	print FID_all '</html>',"\n";
	close FID_all;
	close FID_all_text;
	if (@main::tt_arg_grid){
		my @sub_names;
		@sub_names = @acc_names_with_overall;
		@sub_names = @acc_names_r if $main::regress;
		shift @sub_names;
		my $n = 0;
		map{	
			#Add the tails to the HTML outputs
			modify_sub_tables($sub_all_handle[$n] , $_ , 'end');									
			close $sub_all_handle[$n];
			close $sub_all_handle_text[$n];

			$n++;
		}@sub_names;
	}
}

#*******************************************************************
#
# Function Name: modify_sub_tables($file_handle , $subname , 
#				$statue , $istext , $out_accs_p)
#
# Description: 
#
#		This function is only for parameter optimaztion
#		Create a sortable table and print some outputs into it
#
# Parameters:
#
# 		$file_handle: The file handle for the outfile
#		$subname: The name of the specified criterion (such ACC or MCC)
#		$statue: 'head' / 'body' / 'end'
#		$istext: if the value is 1, print the TEXT format
#		$out_accs_p: The reference of the @out_accs
#		
# Return:
#
#		none
#
#*********************************************************************

sub modify_sub_tables{
	#This function is only for parameter optimaztion:
	#Create the file handles and add some basich infomations
	#Close the files
	my ($file_handle , $subname , $statue , $istext , $out_accs_p) = @_;
	
	if($statue eq 'head'){
		#head
		print $file_handle '<!DOCTYPE html>',"\n";
		print $file_handle '<html>',"\n",'<head>',"\n",'<title>','All of the details for best ',$subname,'</title>',"\n";
		print $file_handle '<script type="text/javascript" src="../tableSort.js"></script>',"\n";#src of the sort table
		print $file_handle '<style type="text/css">',"\n",'@import url("../style.css");',"\n",'</style>',"\n",'</head>',"\n";
		print $file_handle '<body>',"\n";
		#LOGO
		print $file_handle '<a><img src = "logo.gif" ></a>',"\n";
		print $file_handle '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
		print $file_handle '<h2>Modeling Results</h2>',"\n";
		print $file_handle 'This table conatin the results of different modeling methods with the best ' . $subname . ':<br>',"\n";
		print $file_handle 'Click the table headers to sort the results by that colunm<br>',"\n";
		print $file_handle join "\n",print_acc_all_head( 1);
		print $file_handle "\n";
		print $file_handle '<tbody>',"\n";
	}
	elsif($statue eq 'body'){
		my @out_accs = @$out_accs_p;
		my @out, my $i, my $j, my $line;
		our @acc_names;
		our @acc_names_with_overall;
		if ($istext){
			for $i(0..$#out_accs){
				
				for $j(1..$#{$out_accs[0]}){
					$line =  round($out_accs[$i][$j],$main::round_l) . "\t";
					push(@out,$line);
				}
				$line =  'complete/results/' . $out_accs[$i][0] . "\n";
				push(@out,$line);
				
				#push(@out,"\n");
			}
		}
		else{	
			for $i(0..$#out_accs){
				push(@out,'<tr>');
				$line = '    <td align= "right">' . $out_accs[$i][0] . '</td>';
				push(@out,$line);
				for $j(1..$#{$out_accs[0]}){
					$line = '    <td align= "right">' . round($out_accs[$i][$j],$main::round_l) . '</td>';
					push(@out,$line);
				}
				push(@out,'</tr>');
			}
		}
		#Write the table
		if(!$istext){
			flock($file_handle,2);
			print $file_handle join "\n",@out;
			print $file_handle "\n";
			flock($file_handle,8);
		}
		else{
			flock($file_handle,2);
			print $file_handle @out;
			flock($file_handle,8);
		}
	}
	elsif($statue eq 'end'){
		print $file_handle '</tbody>',"\n";
		print $file_handle '</table>',"\n";
		
		print $file_handle 'The \'_O\' means the \'Overall\' description.<br>',"\n" if !$main::regress;
		print $file_handle 'For more details of these evaluation criteria, please click <a href = ./para_explanation.html><U>here</U></a>.';
		
		print $file_handle '<p><a href="../results.html"><U>Back to home page</U></a></p>',"\n";
		print $file_handle '</body>',"\n";
		print $file_handle '</html>',"\n";
	}
}

#*******************************************************************
#
# Function Name: read_html_list_nf( $nf_file )
#
# Description: 
#
#		Read the average values of evaluation criterions about outer 
#		folds in the file generated by function analysis_nfold()
#
# Parameters:
#
# 		$nf_file: The name of the n-fold cross validation
#		
# Return:
#
#		Matrix (2-dimention ARRAY) of the evaluation criterions about 
#		the outer folds of the specified n-fold validation.
#
#*********************************************************************

sub read_html_list_nf{
	#Read the average values of evaluation criterions of the outer folds in the file generated by function analysis_nfold.
	my $file = $_[0];
	open(FID,"$main::prog_dir/results/$main::name/results/$file" . '.html');
	my ($switch,$row) = ( 0 , 0 );
	my @line, my @out; my @out_list;
	while (my $line = <FID>){
		if ($line =~ /^The evaluation criteria of all the outer folds are:/){
			$switch = 1;
		}
		elsif ($line =~ /^\<tr\>/ && $switch == 1){
			$row++;
		}
		elsif ($line =~ /\<td align= "right"\>([^\<]+)\</ && $row && $row > 1 && $switch == 1){
			push @line,$1;
		}
		#elsif ($line =~ /\<td align= "right"\>([^\<]+)\</ && !$row && $switch){
		#	print $file;
		#}
		elsif ($line =~ /^\<\/tr\>/ && $switch == 1 && $row > 1){
			#@out = @line;
			push @out_list,[@line[1..$#line]];
			@line = ();
		}
		elsif ($line =~ /\<\/table\>/ && $switch){
			$switch = 0;
			last;
		}
		elsif ($line =~ /There are some error tasks in this n-fold compute:/){
			return 'err';
		}
	}
	close FID;
	
	#pop @out_list if $main::independent_data
	
	#map{push @out,@{$_}}@out_list[$#out_list - 3 , $#out_list] if !$main::regress;
	map{push @out,@{$_}}@out_list[int($#out_list / 2) , $#out_list] if !$main::regress;
	@out = @{$out_list[$#out_list]} if $main::regress;
	return 'Average',@out;
}

#*******************************************************************
#
# Function Name: update_best_acc(\@best_accs , \@acc , 
#				$method_name , $is_overall)
#
# Description: 
#
#		Compare the @acc with @best_acc and update the records if 
#		some evaluation criterions in @acc are better
#
# Parameters:
#
# 		@best_accs: Records of the best methods for each evaluation criterion
#		@acc: The evaluation criterion of a prediction
#		$method_name: The name of the used method
#		$is_overall: Valued as 1 if the @acc and @best_acc is for overall analysis
#		
# Return:
#
#		None
#
#*********************************************************************

sub update_best_acc{
	#Compare the @acc with @best_acc and update the records if some evaluation criterions in @acc are better. 
	#note that $#best_acc is less than $#accs 1
	#Note that not all the parameters are regarded as larger is better
	my ($best_accs_l,$acc_l,$gd_name , $is_overall)=@_;
	our @acc_names, our @acc_names_r;
	my @minus_list;
	if ($main::regress){
		@minus_list = 2..5;
	}
	else{
		@minus_list = (2,7);
		@minus_list = (2,7,11,16) if $is_overall;
	}
	#if ($main::regress){
	#	map{$$acc_l[0][$_] *= -1; $$best_accs_l[2][$_ - 1] *= -1}@minus_list;
	#	for my $i(1..$#{$$acc_l[0]}){
	#		if ($$acc_l[0][$i] >= $$best_accs_l[2][$i - 1] || $$best_accs_l[2][$i - 1] == 0){
	#			$$best_accs_l[1][$i - 1] = $gd_name;
	#			$$best_accs_l[2][$i - 1] = $$acc_l[0][$i];
	#		}
	#	}
	#	map{$$acc_l[0][$_] *= -1; $$best_accs_l[2][$_ - 1] *= -1}@minus_list;
	#}
	#else{
		map{$$acc_l[$_] *= -1; $$best_accs_l[2][$_ - 1] *= -1 if $$best_accs_l[2][$_ - 1] ne 'init'}@minus_list;
		for my $i(1..$#$acc_l){
			if ($$best_accs_l[2][$i - 1] eq 'init' || $$acc_l[$i] > $$best_accs_l[2][$i - 1]){
				$$best_accs_l[1][$i - 1] = $gd_name;
				$$best_accs_l[2][$i - 1] = $$acc_l[$i];
			}
			elsif($$acc_l[$i] == $$best_accs_l[2][$i - 1]){
				$$best_accs_l[1][$i - 1] .= '<br>'.$gd_name;
			}
		}
		map{$$acc_l[$_] *= -1; $$best_accs_l[2][$_ - 1] *= -1}@minus_list;
	#}
}

#*******************************************************************
#
# Function Name: init_best_accs(\@best_accs , $isoverall)
#
# Description: 
#
#		Initialize a matrix (2-dimention ARRAY) to record the 
#		best methods for each evaluation criterion
#
# Parameters:
#
# 		@best_accs: The records of the best methods for each evaluation criterion
#		$isoverall: Whether to initialize @best_accs for overall analysis
#		
# Return:
#
#		None
#
#*********************************************************************

sub init_best_accs{
	my $best_accs_l = $_[0];my $is_overall = $_[1];
	our @acc_names, our @acc_names_r, our @acc_names_with_overall;
	my @out;
	if ($main::regress){
		push @out,[@acc_names_r[1..$#acc_names_r]];
		push @out,[map{''}@acc_names_r[1..$#acc_names_r]];
		push @out,[map{'init'}@acc_names_r[1..$#acc_names_r]];
	}
	elsif ($is_overall){
		push @out,[@acc_names_with_overall[1..$#acc_names_with_overall]];
		push @out,[map{''}@acc_names_with_overall[1..$#acc_names_with_overall]];
		push @out,[map{'init'}@acc_names_with_overall[1..$#acc_names_with_overall]];
	}
	else{
		push @out,[@acc_names[1..$#acc_names]];
		push @out,[map{''}@acc_names[1..$#acc_names]];
		push @out,[map{'init'}@acc_names[1..$#acc_names]];
	}
	#@$best_accs_l = @out;
	map{
		my $x=$_;
		map{
			$$best_accs_l[$x][$_]=$out[$x][$_];
		}0..$#{$out[$x]};
	}0..$#out;
}

#*******************************************************************
#
# Function Name: get_related_name(\%hash_clu_num , \%hash_num_clu ,
#			 \%hash_fea_num , \%hash_num_fea , \%hash_tt_num , \%hash_num_tt)
#
# Description: 
#
#		Add information of the serial numbers and related method names into the hash indexes
#
# Parameters:
#
# 		%hash_clu_num: The name of cluster methods with the serial numbers
#		%hash_num_clu: The serial numbers with the name of cluster methods
#		%hash_fea_num: The name of variable selection methods with the serial numbers
#		%hash_num_fea: The serial numbers with the name of variable selection methods
#		%hash_tt_num: The name of modeling methods with the serial numbers
#		%hash_num_tt: The serial numbers with the name of modeling methods
#		
# Return:
#
#		None
#
#*********************************************************************

sub get_related_name{
	my ($hash_clu_num_l , $hash_num_clu_l , my $hash_fea_num_l , my $hash_num_fea_l , my $hash_tt_num_l , my $hash_num_tt_l) = @_;
	my $line; my $id; my $type; my $arg_id;
	#clu
	if (grep{$_ eq 'clu'}@main::step){
		$$hash_clu_num_l{'skipClu'} = "clu_-1";
		$$hash_num_clu_l{"clu_-1"} = 'skipClu';
		open (FID,"$main::prog_dir/config/cluster");
		while ($line = <FID>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line !~ /^#/ && $line =~ /^(\d+)\.(\w+)/){
				$id = $1; $type = $2;
				$arg_id = shift @{[grep{$main::cluster_arg[$_ - 1] == $id}(1 .. $#main::cluster_arg + 1)]};
				if($arg_id){
					$arg_id--;
					$line =~ s/\n$//;
					my $name = splice @{[split / /,$line]},1,1;
					if ($type eq 'weka'){
						$name = pop @{[split /\./,$name]};
					}
					$$hash_clu_num_l{$name} = "clu_$arg_id";
					$$hash_num_clu_l{"clu_$arg_id"} = $name;
				}
			}
		}
		close FID;
	}
	#fea
	if (grep{$_ eq 'fea'}@main::step){
		$$hash_fea_num_l{'skipVar'} = "fea_-1";
		$$hash_num_fea_l{"fea_-1"} = 'skipVar';
		open (FID,"$main::prog_dir/config/feature");
		while ($line = <FID>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line !~ /^#/ && $line =~ /^(\d+)\.(\w+)/){
				$id = $1; $type = $2;
				$arg_id = shift @{[grep{$main::feature_select_arg[$_ - 1] == $id}(1 .. $#main::feature_select_arg + 1)]};
				if($arg_id){
					$arg_id--;
					$line =~ s/\n$//;
					my $name = splice @{[split / /,$line]},1,1;
					if ($type eq 'weka'){
						$name = pop @{[split /\./,$name]};
					}
					$$hash_fea_num_l{$name} = "fea_$arg_id";
					$$hash_num_fea_l{"fea_$arg_id"} = $name;
				}
			}
		}
		close FID;
	}
	#tt
	if (grep{$_ eq 'tt'}@main::step){
		open (FID,"$main::prog_dir/config/traintest");
		while ($line = <FID>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line !~ /^#/ && $line =~ /^(\d+)\.(\w+)/){
				$id = $1; $type = $2;
				$arg_id = shift @{[grep{$main::tt_arg[$_ - 1] == $id}(1 .. $#main::tt_arg + 1)]};
				if($arg_id){
					$arg_id--;
					$line =~ s/\n$//;
					my $name = splice @{[split / /,$line]},1,1;
					if ($type eq 'weka'){
						$name = pop @{[split /\./,$name]};
					}
					$$hash_tt_num_l{$name} = "tt_$arg_id";
					$$hash_num_tt_l{"tt_$arg_id"} = $name;
				}
			}
		}
		close FID;
	}
}

#*******************************************************************
#
# Function Name: replace_out_name($task_name , $condition)
#
# Description: 
#
#		Convert the task name for human readable
#
# Parameters:
#
# 		$taks_name: The name of task generated by PML
#		$condition: 0, 1, 2
#		
# Return:
#
#		The converted name which depend on the value of $condition:
#		$condition = 0 : Default, just return the readable name
#		$condition = 1 : Return the shortest name for the data process tree
#		$condition = 2 : Return the readable name with its type which generated by function replace_job_type
#
#*********************************************************************

sub replace_out_name{
	my ($name,$islast) = @_;
	$islast = 0 if !$islast;
	my $type;#Cluster£¬VarSelection£¬ModelingIn , ModelingOut, ParaOptimization , CrossValidation
	our @related_names;
	my $related_names_l = \@related_names;
	
	$name =~ s/^$main::name//s;
	$name =~ s/^_train_//;
	my @elements = split /_/,$name;
	my @out_names;
	while ($elements[0] ne 'tt' && $#elements > 2){
		my $out_name = join '_',@elements[0..2];
		$out_name =~ s/^(clu_-?\d+)/$$related_names_l[1]{$1}/s if $elements[0] eq 'clu';
		$out_name =~ s/^(fea_-?\d+)/$$related_names_l[3]{$1}/s if $elements[0] eq 'fea';
		push @out_names,$out_name;
		splice @elements,0,3;
	}

	my $out_name = join '_',@elements;
	$type = replace_job_type($out_name);
	$out_name =~ s/^(clu_-?\d+)/$$related_names_l[1]{$1}/s if $elements[0] eq 'clu';
	$out_name =~ s/^(fea_-?\d+)/$$related_names_l[3]{$1}/s if $elements[0] eq 'fea';
	$out_name =~ s/^(tt_\d+)/$$related_names_l[5]{$1}/s if $elements[0] eq 'tt';
	push @out_names,$out_name;
	if ($islast == 1){
		my $last_name = pop @out_names;
		$last_name =~ s/_grid$//;
		$last_name =~ s/_nfold$/_CV/;
		$last_name =~ s/(_inner_\d+)_outer_\d+$/$1/;
		
		return $last_name,$type;
	}
	elsif($islast == 2){
		$out_names[$#out_names] =~ s/_grid$//;
		$out_names[$#out_names] =~ s/_nfold$//;
		$out_names[$#out_names] =~ s/(_inner_\d+)_outer_\d+$/$1/;
		$out_names[$#out_names] =~ s/_independent$//;
		return @out_names,"_$type";
	}
	return join '_',@out_names;
	
}

#*******************************************************************
#
# Function Name: replace_job_type( $task_name )
#
# Description: 
#
#		Convert the types of tasks for human readable
#		Convert the clu, fea, grid, nfold, outer, inner , IndepTest  
#		to Cluster, VarSelection, ParaOptimization, CrossValidation, 
#		ModelingOut, ModelingIn, IndependentTest
#
# Parameters:
#
# 		$taks_name: The name of task generated by PML
#		
# Return:
#
#		The converted type.
#
#*********************************************************************

sub replace_job_type{
	#Convert the types of tasks for human readable.
	my $out_name = $_[0];
	my $type;
	$type = 'Cluster' if $out_name =~ /^clu/;
	$type = 'VarSelection' if $out_name =~ /^fea/;
	$type = 'ParaOptimization' if $out_name =~ /_grid$/;
	$type = 'CrossValidation' if $out_name =~ /_nfold$/;
	$type = 'ModelingOut' if $out_name =~ /_outer_/;
	$type = 'ModelingIn' if $out_name =~ /_inner_/;
	$type = 'IndepTest' if $out_name =~ /_independent$/;
	return $type;
}

#*******************************************************************
#
# Function Name: dircopy($dir_source , $dir_target)
#
# Description: 
#		Copy the folder.
#
# Parameters:
#
# 		$dir_source: The path of the source folder
#		$dir_target: The target path of the copy
#
# Return:
#
#		None
#
#*********************************************************************

sub dircopy{
	#copy folders
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

#*******************************************************************
#
# Function Name: retry_detail($step , $isweka)
#
# Description: 
#		Return some prompt for users to retry a task.
#
# Parameters:
#
# 		$step: clu, fea or tt
#		$isweka: if the related task used weka
#
# Return:
#
#		ARRAY with strings of HTML format
#
#*********************************************************************

sub retry_detail{
	#Return some prompt for users to retry a task.
	my ($step , $isweka) = @_;
	my @lines;
	push @lines,'If you want to retry this task, some steps are needed:';
	push @lines,'Create an independent folder anywhere, assume the name of the folder is <I>retry</I>.';
	push @lines,'Save the <B>Input data file</B> as <B>data.arff</B> into the folder <I>retry</I>.' if $step ne 'tt';
	push @lines,'Save the <B>Train data file</B> as <B>train.arff</B> into the folder <I>retry</I>.' if $step eq 'tt';
	push @lines,'Save the <B>Test data file</B> as <B>test.arff</B> into the folder <I>retry</I>.' if $step eq 'tt';
	push @lines,'Save the <B>Script file</B> as <B>script</B> into the folder <I>retry</I>.' if $isweka;
	push @lines,'Save the <B>Script file</B> as <B>files.tgz</B> into the folder <I>retry</I>.' if !$isweka;	
	push @lines,'Save the <B>Jop property file</B> as <B>step_prop</B> into the folder <I>retry</I>.';
	push @lines,'Save the file <a href="../processor_single.pl">processor_single.pl</a> into the folder <I>retry</I>.';
	push @lines,'Save the file <a href="../weka.jar">weka.jar</a> into the folder <I>retry</I>.' if $isweka;
	push @lines,'Make a command line window and set the work directory(e.g. use command \'cd\') under the folder <I>retry</I>, and run this command line below:';
	push @lines,'<br><I>perl processor_single.pl</I><br>';
	push @lines,'If the script(or files) is right, there will be an output file <B>out.txt.arff</B> finally.' if $step ne 'tt';
	push @lines,'If the script(or files) is right, there will be an output file <B>out.txt.pre</B> finally.' if $step eq 'tt';
	push @lines,'Otherwise, some errors would occur, and you could check the problems in this folder.';
	my $line = join('<br>' . "\n" , @lines);
	$line = '<p>' . $line . '</p>';
	return $line;
}

#*******************************************************************
#
# Function Name: show_time()
#
# Description: 
#		Show the time
#
# Parameters:
#
# 		None
#
# Return:
#
#		The time with the format: hour:min:sec in year/mon/day
#
#*********************************************************************

sub show_time{
	my ($sec , $min , $hour , $day , $mon , $year) = localtime();
	$year += 1900;
	$mon++;
	return "$hour:$min:$sec in $year/$mon/$day";
}

#*******************************************************************
#
# Function Name: show_process_err($job_name , $del_jobs , $complete_jobs_l , $total_jobs_l)
#
# Description: 
#		Show the number of cancled tasks and updated progress
#
# Parameters:
#
# 		$job_name: The name of the err task
#		$del_jobs: The number of cancled tasks
#		$complete_jobs_l: The reference of the number of completed tasks
#		$total_jobs_l: The reference of the number of all the tasks
#
# Return:
#
#		None
#
#*********************************************************************

sub show_process_err{
	#If a task has crashed, this function could generate a message about the name of failed task and the reduced number of tasks.
	my ($job_name , $del_jobs , $complete_jobs_l , $total_jobs_l) = @_;
	print "\n",'Task ' . replace_out_name($job_name) . " is canceled by $main::retry_threshold times of retry\n";
	#The error task would be considered as completed.
	$del_jobs -= 1;
	$$complete_jobs_l += 1;
	print "Related $del_jobs task(s) have been canceled.\n" if $del_jobs;
	$$total_jobs_l -= $del_jobs;
	
	print $$complete_jobs_l . ' tasks completed, ' . ($$total_jobs_l -  $$complete_jobs_l) . ' tasks remaining, ' . $$total_jobs_l . ' tasks in total.' . "\n";
	
}

#*******************************************************************
#
# Function Name: show_process_err($complete_jobs , $total_jobs)
#
# Description: 
#		Show a progress bar of the current progress.
#
# Parameters:
#
#		$complete_jobs: The number of completed tasks
#		$total_jobs: The number of all the tasks
#
# Return:
#
#		None
#
#*********************************************************************

sub show_out_files_progress{
	#Show a progress bar of the current progress.
	my ($complete_jobs,$total_jobs) = @_;
	my $process = $complete_jobs / $total_jobs;
	my $bar_lenth = 40;
	my $bar_com = int($bar_lenth * $process) - 1;
	my $bat_left = $bar_lenth - ($bar_com>0?$bar_com:0) - 1;
#	$bar_com = $bar_lenth , $bat_left = 0 if length($bar_com) > $bar_lenth;
#	$bat_left = $bar_lenth , $bar_com = 0 if length($bat_left) > $bar_lenth;
	my $process_bar = '[' . '=' x $bar_com . '>' . ' ' x $bat_left . ']';
	local $| = 1;
	print "\r$process_bar ";
	printf "%.2f",($complete_jobs / $total_jobs * 100);
	print '% '.$complete_jobs." / ".$total_jobs;
	local $| = 0;
}
1;
__END__



