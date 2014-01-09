#!/usr/bin/perl
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

BEGIN{
	our $prog_dir = './pml';
	push @INC,"$prog_dir/src";
}

use File::Copy;
use threads;
use warnings;
use strict;

#PML-Desktop

#help
my $help_control;
$help_control = 1 if grep{$_ eq '-h' || $_ eq '--help'}@ARGV;
$help_control = 1 if scalar @ARGV == 0;
if ($help_control){
	print "Useage:\n";
	print "pml_desktop.pl input_script [option]\n";
	print "\noption:\n";
	print "--help or -h \t Show this help text\n";
	print "--reset \t Reset the experiment firstly\n";
	print "\nExample:\n";
	print "pml_desktop.pl pml/examples/muti_method_PO_classify\n";
	print "\nMore details can be found in PML manual.pdf\n\n";
	exit;
}

our $prog_dir;

use pml::init;
use pml::job;
use pml::result;

print "Initializing...\n";
die "Can not detect the input script, please confirm the path of the script." if !-f $ARGV[0];
open(FID_c,"$ARGV[0]");
our @step;

my $i;

#switchs
my $cluster_s = 0; my $feature_s = 0; my $tt_s = 0;

#inner and outer folds
our $outer_folds = 0;	our $inner_folds = 0;

#data cluster
our (@cluster_arg , @cluster_arg_grid , $cluster_arg_grid_file , @cluster_out_instances);

#variable select
our (@feature_select_arg , @feature_arg_grid , $feature_arg_grid_file , @feature_out_features);

#modeling(train test)
our (@tt_arg , @tt_arg_grid , $tt_arg_grid_file);

#corss validation
our (@inner_fold_train_files , @inner_fold_test_files , @outer_fold_train_files , @outer_fold_test_files);

#The name of the experiment
our $name;

#The path of the data file
my $data_file;

#specify the train and test data
our ($train_file , $test_file_serial , $test_file);

#Memory usage of weka
our $max_memory = '1g';

#Seeds
our $globle_seed = 1;
our $seed_outer = $globle_seed , our $seed_inner = $globle_seed, our $seed_clu = $globle_seed , our $seed_fea = $globle_seed;

#independent test
our ($independent_data , $one_out_per_opt);

#flow control
my $sleep_time = 0;
our $time_limit_result = 300;
our $core_number;
our $silent;
our $time_limit_task = 86400;
my (%hash_running , %hash_wus , %hash_wait , %hash_wait_id , %hash_id_time);

#task packing
our $task_tar_num = 0;#The compress number of tasks
our $task_devide_num = 1;#The estimated devide number
our $task_create_count = 0;

#some other variables
our $feautre_threshold = 0;
our $cluster_train_file;
our $retry_threshold = 3;
our $compress_level = 9;
our $round_l = 4;#the level of round, 4 means keep 4 decimal places (4.563758 => 4.5638)


my $line;
while($line = <FID_c>){
	$line =~ s/\s*$//;
	if ($line =~ m/^NAME\s*=\s*([^\n]+)/i){
		$name = $1;
	}
	elsif ($line =~ m/^FILE\s*=\s*([^\n]+)/i){
		$data_file = $1;
		$data_file =~ s/[\\]+/\//g;
	}
	elsif ($line =~ m/^MAX_MEMORY\s*=\s*([^\n]+)/i){
		$max_memory = $1;
	}
	elsif ($line =~ m/^STEP\s*=\s*([^\n]+)/i){
		@step = split(m/\s*,\s*/,$1);
	}
	elsif($line =~ m/^CLUSTER_ARG\s*=\s*([^\n]+)/i){
		$cluster_s = 1;
		map{
			my @units = split /-/,$_;
			push @cluster_arg,$units[0]..$units[$#units];
		}split(m/\s*,\s*/,$1);
		#push @cluster_arg , split(m/\s*,\s*/,$1);
	}
	elsif($line =~ m/^CLUSTER_OUT_INSTANCES\s*=\s*([^\n]+)/i && $cluster_s == 1){		push @cluster_out_instances,split(m/\s*,\s*/,$1);	}
	elsif($line =~ m/^CLUSTER_ARG_OPT\s*=\s*([^\n]+)/i){	
		push @cluster_arg_grid , get_split_grid(',',$1);
		map{$_ =~ s/^\s+//; $_ =~ s/\s+$//;}@cluster_arg_grid;
	}
	elsif($line =~ m/^CLUSTER_ARG_OPT_FILE\s*=\s*([^\n]+)/i){	$cluster_arg_grid_file = $1;}
	elsif($line =~ m/^FEATURE_SELECT_ARG\s*=\s*([^\n]+)/i){
		$feature_s = 1;
		map{
			my @units = split /-/,$_;
			push @feature_select_arg,$units[0]..$units[$#units];
		}split(m/\s*,\s*/,$1);
		#push @feature_select_arg , split(m/\s*,\s*/,$1);
	}
	elsif($line =~ m/^FEATURE_OUT_FEATURES\s*=\s*([^\n]+)/i && $feature_s == 1){		push @feature_out_features , split(m/\s*,\s*/,$1);	}
	elsif($line =~ m/^FEATURE_ARG_OPT\s*=\s*([^\n]+)/i){	
		push @feature_arg_grid , get_split_grid(',',$1);
		map{$_ =~ s/^\s+//; $_ =~ s/\s+$//;}@feature_arg_grid;
	}
	elsif($line =~ m/^FEATURE_ARG_OPT_FILE\s*=\s*([^\n]+)/i){	$feature_arg_grid_file = $1;}
	elsif($line =~ m/^TT_ARG\s*=\s*([^\n]+)/i){
		$tt_s = 1;
		map{
			my @units = split /-/,$_;
			push @tt_arg,$units[0]..$units[$#units];
		}split(m/\s*,\s*/,$1);
		#push @tt_arg , split(m/\s*,\s*/,$1);
	}
	elsif($line =~ m/^TT_ARG_OPT\s*=\s*([^\n]+)/i && $tt_s == 1){		
		push @tt_arg_grid , get_split_grid(',',$1);
		map{$_ =~ s/^\s+//; $_ =~ s/\s+$//;}@tt_arg_grid;
	}
	elsif($line =~ m/^TT_ARG_OPT_FILE\s*=\s*([^\n]+)/i && $tt_s == 1){		$tt_arg_grid_file = $1;	}
	elsif($line =~ m/^INNER_FOLDS\s*=\s*([^\n]+)/i && $tt_s == 1){		$inner_folds = $1;	}
	elsif($line =~ m/^OUTER_FOLDS\s*=\s*([^\n]+)/i && $tt_s == 1){		$outer_folds = $1;	}
	elsif($line =~ m/^INNER_FOLD_TRAIN_FILES_SERIAL\s*=\s*([^\n]+)/i && $tt_s == 1){		push @inner_fold_train_files , split(/\s*,\s*/,$1);	}
	elsif($line =~ m/^INNER_FOLD_TEST_FILES_SERIAL\s*=\s*([^\n]+)/i && $tt_s == 1){		push @inner_fold_test_files , split(/\s*,\s*/,$1);	}
	elsif($line =~ m/^OUTER_FOLD_TRAIN_FILES_SERIAL\s*=\s*([^\n]+)/i && $tt_s == 1){		push @outer_fold_train_files , split(/\s*,\s*/,$1);	}
	elsif($line =~ m/^OUTER_FOLD_TEST_FILES_SERIAL\s*=\s*([^\n]+)/i && $tt_s == 1){		push @outer_fold_test_files , split(/\s*,\s*/,$1);	}
	elsif($line =~ m/^TRAIN_FILE\s*=\s*([^\n]+)/i && $tt_s == 1){		$train_file = $1;	}
	elsif($line =~ m/^TEST_FILE\s*=\s*([^\n]+)/i && $tt_s == 1){		$test_file = $1;	}
	elsif($line =~ m/^TEST_FILE_SERIAL\s*=\s*([^\n]+)/i && $tt_s == 1){		$test_file_serial = $1;	}
	elsif($line =~ m/^FEATURE_THRESHOLD\s*=\s*([^\n]+)/i && $feature_s == 1){
		$feautre_threshold = $1;
		$feautre_threshold /= 100 if $feautre_threshold > 1;
	}
	elsif($line =~ m/^CLUSTER_TRAIN_FILE\s*=\s*([^\n]+)/i){$cluster_train_file = $1;}
	elsif($line =~ m/^RETRY\s*=\s*([^\n]+)/i){$retry_threshold = $1;}
	elsif($line =~ m/^CORE_NUM\s*=\s*([^\n]+)/i){$core_number = $1;}
	elsif($line =~ m/^COMPRESS_LEVER\s*=\s*([^\n]+)/i){$compress_level = $1;}
	elsif($line =~ m/^SEED\s*=\s*([^\n]+)/i){$globle_seed = $1;}
	elsif($line =~ m/^SEED_CLU\s*=\s*([^\n]+)/i){$seed_clu = $1;}
	elsif($line =~ m/^SEED_INNER\s*=\s*([^\n]+)/i){$seed_inner = $1;}
	elsif($line =~ m/^SEED_OUTER\s*=\s*([^\n]+)/i){$seed_outer = $1;}
	elsif($line =~ m/^SILENT\s*=\s*([^\n]+)/i){$silent = $1;}
	elsif($line =~ m/^TIME_LIMIT_TASK\s*=\s*([^\n]+)/i){$time_limit_task = $1;}
	elsif($line =~ m/^TIME_LIMIT_RESULT\s*=\s*([^\n]+)/i){$time_limit_result = $1;}
	elsif($line =~ m/^SLEEP_TIME\s*=\s*([^\n]+)/i){$sleep_time = $1;}
	elsif($line =~ m/^ROUND_L\s*=\s*([^\n]+)/i){$round_l = $1;}
	elsif($line =~ m/^INDEPENDENT_DATA\s*=\s*([^\n]+)/i){$independent_data = $1;}
	elsif($line =~ m/^ONE_OUT_PER_OPT\s*=\s*([^\n]+)/i){$one_out_per_opt = $1;}
}
close FID_c;

die 'PML can\'t locate the input data file' if !-f $data_file;
if (@outer_fold_test_files || @outer_fold_train_files){
	if (@outer_fold_test_files){
		$outer_folds = $#outer_fold_test_files + 1;
		map{die "Can not detect test file $_ for outer fold, please check it." if !-f $_}@outer_fold_test_files;
	}
	elsif (@outer_fold_train_files){
		$outer_folds = $#outer_fold_train_files + 1;
		map{die "Can not detect train file $_ for outer fold, please check it." if !-f $_}@outer_fold_train_files;
	}
}

die 'OUTER_FOLDS should be larger than 0' if $outer_folds <= 0;
die 'PML can\'t locate the independent test data file' if $independent_data && !-f $independent_data;
if(@inner_fold_test_files || @inner_fold_train_files){
	if (@inner_fold_test_files){
		$inner_folds = $#inner_fold_test_files + 1;
		$inner_folds /= $outer_folds;
		map{die "Can not detect test file $_ for inner fold, please check it." if !-f $_}@inner_fold_test_files;
	}
	elsif(@inner_fold_train_files){
		$inner_folds = $#inner_fold_train_files + 1;
		$inner_folds /= $outer_folds;
		map{die "Can not detect train file $_ for inner fold, please check it." if !-f $_}@inner_fold_train_files;
	}
}

init_pml_job();
init_pml_result();

reset_desktop("$prog_dir/results/$name") if $ARGV[1] && $ARGV[1] eq '--reset';


#get core number
my $core_muti = 1;
if ($core_number && $core_number =~ /^x([\d\.]+)/i){
	$core_muti = $1;
}

$core_number = get_threads_number() if !$core_number || $core_number =~ /^x([\d\.]+)/i || $core_number < 1;
$core_number = 1 if !$core_number || $core_number < 1;
$core_number = int($core_muti * $core_number);
for $i(1..$core_number){
	$hash_wus{"wu$i"} = 0;
}

creat_floders();

#estimate the number of tasks
my %hash_task;
my $total_job_num = get_job_num(\%hash_task);
my $complete_job_num = 0;

my $instance;	our $is4class;
my $attribute, my $miss;
copy($data_file , "$prog_dir/results/$name/orgdata/" . pop @{[split /\//,$data_file]});
($instance,$attribute,$is4class,$miss)=analysis_data($data_file,"$prog_dir/results/$name/orgdata/datainfo.txt");
$data_file = pop @{[split /\//,$data_file]};
our $regress = !$is4class;

die 'Data '.$data_file.' have no instance, please check it again' if !$instance;
die 'Data '.$data_file.' have no attribute, please check it again' if !$attribute;

show_detail($instance,$attribute,$is4class,$total_job_num);

#Change the out number of cluster
if (@cluster_out_instances){
	for (@cluster_out_instances){
		next if $_ eq 'all';
		$_ = int($_ * $instance) if $_ < 1;
		$_ = 1 if $_ < 1;
	}
}

#add the parameter optimization details from files if provided
if($tt_arg_grid_file){
	open(FID_OUT,$tt_arg_grid_file);
	@tt_arg_grid = grep{m/^[^\n\#]/}<FID_OUT>;
	map{$_ =~ s/\s+$//;}@tt_arg_grid;
	close FID_OUT;
}

if($cluster_arg_grid_file){
	open(FID_OUT,$cluster_arg_grid_file);
	@cluster_arg_grid = grep{m/^[^\n\#]/}<FID_OUT>;
	map{$_ =~ s/\s+$//;}@cluster_arg_grid;
	close FID_OUT;
}

if($feature_arg_grid_file){
	open(FID_OUT,$feature_arg_grid_file);
	@feature_arg_grid = grep{m/^[^\n\#]/}<FID_OUT>;
	map{$_ =~ s/\s+$//;}@feature_arg_grid;
	close FID_OUT;
}

if (!@cluster_out_instances){ @cluster_out_instances = ('all');}
if (!@feature_out_features){ @feature_out_features = ('all');}
if (!@cluster_arg_grid){ @cluster_arg_grid = ('null')};
if (!@feature_arg_grid){ @feature_arg_grid = ('null')};
if (!@tt_arg_grid){ @tt_arg_grid = ('null')};
if (!$outer_folds){ $outer_folds = 10;}
elsif ($outer_folds eq 'all'){$outer_folds = $instance;}
my $each_out_fold = $instance - int($instance / $outer_folds);

#Decide if this experiment has started before
my $isbegin;
if (-e "$prog_dir/results/$name/orgdata/begin"){
	open(FID_S,"$prog_dir/results/$name/orgdata/begin");
	$line = <FID_S>;
	if ($line =~ /^1/){
		$isbegin = 1;
	}
	close FID_S;
	
}
if (!$isbegin){
	if ($test_file_serial){
		data_copy("$prog_dir/results/$name/orgdata/$data_file","$prog_dir/results/$name/data/$name".'.arff');
		my @rand_sequence = ([1..$instance]);
		my @data_detail=analysis_data_j("$prog_dir/results/$name/data/$name".'.arff');
		my (@train_test_list)=get_train_test_list(0,1,1,1,\@{[($test_file_serial)]},\@{[()]},\@rand_sequence);
		print_one_fold("$prog_dir/results/$name/data/$name",'' ,0,\@data_detail, [@train_test_list]);
	}	
	elsif($test_file){
		copy($test_file , "$prog_dir/results/$name/orgdata/test_data");		
		data_copy("$prog_dir/results/$name/orgdata/$data_file","$prog_dir/results/$name/data/$name".'_train.arff');
		data_copy($test_file,"$prog_dir/results/$name/data/$name".'_test.arff');
	}	
	else{
		data_copy("$prog_dir/results/$name/orgdata/$data_file","$prog_dir/results/$name/data/$name".'_train.arff');
	}
	analysis_data("$prog_dir/results/$name/data/$name".'_train.arff',"$prog_dir/results/$name/data/$name".'_train.info');
	if($independent_data){
		data_copy($independent_data,"$prog_dir/results/$name/orgdata/independent.arff");
	}
}
else{
	opendir(DIR_S,"$prog_dir/results/$name/status");
	my @sfiles = readdir(DIR_S);
	closedir DIR_S;
	foreach my $sfile(@sfiles){
		next if !-f "$prog_dir/results/$name/status/$sfile";
		open(FID,"$prog_dir/results/$name/status/$sfile");
		my $sline = <FID>;
		close FID;
			if ($sline =~ /^2/ || $sline =~ /^3/){
			open(FID,">$prog_dir/results/$name/status/$sfile");
			print FID '1';
			close FID;
		}
	}
	if (!$silent){
		my @complete_files = <$prog_dir/results/$name/complete/*>;
		@complete_files = grep{-f $_}@complete_files;
		$complete_job_num += scalar @complete_files;
		my @err_files = <$prog_dir/results/$name/err/*>;
		@err_files = grep{-f $_}@err_files;
		map{$total_job_num -= (del_job_num($_,\%hash_task) - 1)}@err_files if @err_files;
	}
	
}

#reset the wu folders
rmtree("$prog_dir/wus");
init_wu();
map{$hash_wus{"wu$_"}=0;}$core_number;
unlink "pml_theads_err.log" if -f "pml_theads_err.log";
#reset related details in folder sample_results
{
	my @result_files = <sample_results/*>;
	my $namec = $name . '_train_clu';
	my $namef = $name . '_train_fea';
	my $namet = $name . '_train_tt';
	map{
		unlink $_ if -f $_ && ($_ =~ /$namec/s || $_ =~ /$namef/s || $_ =~ /$namet/s) ;
	}@result_files;

}
$independent_data = "$prog_dir/results/$name/orgdata/independent.arff" if $independent_data;
####################################################################################################################

#begin to generate the first scripts
my $script_name = $name . '_train';

if (!$isbegin && @step){
	if ($step[0] eq 'clu'){creat_job_clu($script_name,$name,$max_memory,[@cluster_arg],[@cluster_arg_grid],[@cluster_out_instances]);}
	elsif ($step[0] eq 'fea'){creat_job_fea($script_name,$name,$max_memory,[@feature_select_arg],[@feature_arg_grid],[@feature_out_features]);}
	elsif ($step[0] eq 'tt'){
		data_for_tt($script_name);
		data_for_independent($script_name) if $independent_data;
		creat_job_tt($script_name,$name,$max_memory,[@tt_arg],[@tt_arg_grid],$inner_folds,$outer_folds);
	}
	open(FID_S,">$prog_dir/results/$name/orgdata/begin");
	print FID_S 1;
	close FID_S;
}
elsif(!@step) {die("need to confirm the STEP option");}

#monitering the status folder
#
#read the labels in folder $prog_dir/results/$name/status
#label = 1 means the task is waitting to be executed.
#label = 2 means the task is being executed
#label = 3 means complete and the result could be found in folder sample_result,
#          then the scripts for next step (if exists) will be generated.
#
#Tasks with error would be retried automaticaly, if the number of retry times exceed the threshold,
#the task and related files would be moved to the folder pml/results/$name/err
#
#If the status folder is empty, that means all the tasks have been finished.
print "Start to process tasks...\n";
$retry_threshold++;

my $complete_job_num_old = $complete_job_num;

my $statue_dir = "$prog_dir/results/$name/status"; 
my $script_dir = "$prog_dir/results/$name/scripts";
my $out_dir = "sample_results";
opendir(DIR_S,$statue_dir);
my @statue_files = readdir(DIR_S);
closedir DIR_S;
my $each_sfile, my $sfile_size, my $job_created, my $statue_value;
my $out_size, my %out_files;
my @threads = threads->list(threads::all);
#@statue_files contain at least 2 elements: . and .., thus there need to larger than 1
while ($#statue_files > 1){
	for $i(0..$#statue_files){
		$each_sfile = $statue_files[$i];
		if ($each_sfile =~ /~$/){
			unlink "$statue_dir/$each_sfile";
			next;
		}		
		if (-f "$statue_dir/$each_sfile"){
			open(FID_S,"$statue_dir/$each_sfile");
			$line = <FID_S>;
			$line =~ m/^(\d)/;
			$statue_value = $1;
			close FID_S;
			if($statue_value == 1){
				
				if (grep{$hash_wus{"wu$_"} == 0}1..$core_number){
					#check empty wu
					my $wu = shift @{[grep{ $hash_wus{"wu$_"} == 0 }1..$core_number]};
					
					#update the working wus
					$hash_wus{"wu$wu"} = 1;
					
					#create task
					job_creator_desktop($each_sfile,$wu);
					my $thr = threads->create("job_execute_desktop",$wu,$each_sfile,$prog_dir);
					my $thread_id = $thr->tid();
					
					#update running ids
					$hash_running{$thread_id} = "wu$wu";
					$hash_id_time{$thread_id} = time;
					$hash_wait{$each_sfile}=1; $hash_wait_id{$thread_id}=$each_sfile;
					open(FID_S,">$statue_dir/$each_sfile");
					print FID_S '2';
					close FID_S;
					#show_creat_job($each_sfile) if !$silent;
				}
			}
			elsif($statue_value == 2){
				my $isprocessed;
				my $retry_count;
				if ($each_sfile =~ /_retry(\d+)$/){
					my $each_sfile_out = $each_sfile;
					$each_sfile_out =~ s/_retry\d+$//;
					if (!-e "$script_dir/$each_sfile_out"){
						unlink "$statue_dir/$each_sfile";
						next;
					}
				}
				elsif (!-e "$script_dir/$each_sfile"){
					unlink "$statue_dir/$each_sfile";
					next;
				}
				if (-e "$out_dir/$each_sfile"){
					$out_size = -s "$out_dir/$each_sfile";
					if (exists($out_files{$each_sfile})){
						if ($out_files{$each_sfile} == $out_size && -f "$out_dir/$each_sfile" . '_finish'){
							unlink "$out_dir/$each_sfile" . '_finish';
							#rename if the task has name with '_retry' in the end
							if ($each_sfile =~ /_retry(\d+)$/){
								$retry_count = $1;
								my $each_sfile_out = $each_sfile;
								$each_sfile_out =~ s/_retry\d+$//;
								rename("$out_dir/$each_sfile","$out_dir/$each_sfile_out");
								rename("$statue_dir/$each_sfile","$statue_dir/$each_sfile_out");
								$each_sfile = $each_sfile_out;
							}
							else{
								$retry_count = 0;
							}
							if (-s "$out_dir/$each_sfile" == 0){
								$isprocessed = 0;
							}else{
								$isprocessed = file_process_out($each_sfile,@step);
							}
							delete($out_files{$each_sfile}) if exists($out_files{$each_sfile});
							delete($out_files{$each_sfile . "_retry$retry_count"}) if exists($out_files{$each_sfile . "_retry$retry_count"});
							if (!$isprocessed){
								if ($retry_count < $retry_threshold){
									#if error£¬return the status to 1, rename, then retry
									unlink("$out_dir/$each_sfile");
									$retry_count++;
									open(FID_S,">$statue_dir/$each_sfile");
									print FID_S "1";
									close FID_S;
									rename("$statue_dir/$each_sfile","$statue_dir/$each_sfile" . "_retry$retry_count");
								}
								else{
									#if do not need to retry, move them to err folder
									move("$out_dir/$each_sfile","$prog_dir/results/$name/err/results");
									move("$statue_dir/$each_sfile","$prog_dir/results/$name/err");
									move("$script_dir/$each_sfile","$prog_dir/results/$name/err/scripts");
									my $del_jobs = del_job_num($each_sfile,\%hash_task) if !$silent;
									show_process_err($each_sfile,$del_jobs,\$complete_job_num,\$total_job_num) if !$silent;
								}
							}
							else{
								open(FID_S,">$statue_dir/$each_sfile");
								print FID_S '3';
								close FID_S;
							}
						}						
						else{ $out_files{$each_sfile} = $out_size;}
					}
					else {	$out_files{$each_sfile} = $out_size;}
				}
			}
			elsif($statue_value == 3){				
				#Move the related files of the complete task to folder complete
				#Generate the scripts and data files for next step if needed
				my @script_step = split( /_/,$each_sfile);
				shift(@script_step);
				@script_step = grep{$_ =~ m/^[cft]/}@script_step;
				if ($script_step[$#script_step] ne 'tt'){
					my @next_steps = grep{$step[$_] eq $script_step[$#script_step]}(0..$#step);
					my $next_step = pop(@next_steps);
					$next_step = $step[$next_step + 1];
					if ($next_step eq 'clu'){creat_job_clu($each_sfile,$name,$max_memory,[@cluster_arg],[@cluster_arg_grid],[@cluster_out_instances]);}
					elsif ($next_step eq 'fea'){creat_job_fea($each_sfile,$name,$max_memory,[@feature_select_arg],[@feature_arg_grid],[@feature_out_features]);}
					elsif ($next_step eq 'tt'){	
						data_for_tt($each_sfile) if $each_sfile =~ /_all$/;
						data_for_independent($each_sfile) if $each_sfile =~ /_all$/ && $independent_data;
						creat_job_tt($each_sfile,$name,$max_memory,[@tt_arg],[@tt_arg_grid],$inner_folds,$outer_folds);
					}
				}
				move("$out_dir/$each_sfile","$prog_dir/results/$name/complete/results");
				move("$script_dir/$each_sfile","$prog_dir/results/$name/complete/scripts");
				move("$statue_dir/$each_sfile","$prog_dir/results/$name/complete");
				$complete_job_num++ if !$silent && !-f "$statue_dir/$each_sfile";
			}
		}
	}
	foreach my $thread(threads->list(threads::all)){
		my $thread_id = $thread->tid();
		if($thread->is_joinable()){
			#reset wu
			$hash_wus{$hash_running{$thread_id}} = 0;
			#delete relate variables
			delete $hash_running{$thread_id};
			delete $hash_wait{$hash_wait_id{$thread_id}};
			delete $hash_wait_id{$thread_id};
			
			delete $hash_id_time{$thread_id};
			#join the thread
			$thread->join();
		}
		else{
			#if the runtime of the task exceed the time limite, restart or dump it
			if (time - $hash_id_time{$thread_id} > $time_limit_task){
				$thread->exit();
				
				my $retry_count = 0;
				my $job_name = $hash_wait_id{$thread_id};
				if ( $job_name =~ /_retry(\d+)$/){
					$retry_count = $1;
					$job_name =~ s/_retry\d+$//;
				}
				
				if ($retry_count < $retry_threshold){
					unlink("$out_dir/" . $hash_wait_id{$thread_id} );
					$retry_count++;
					
					open(FID_S,">$statue_dir/" . $hash_wait_id{$thread_id});
					print FID_S "1";
					close FID_S;
					rename("$statue_dir/".$hash_wait_id{$thread_id},
					"$statue_dir/$job_name" . "_retry$retry_count");
				}
				else{
					##if do not need to retry, move them to err folder
					move("$out_dir/".$hash_wait_id{$thread_id},"$prog_dir/results/$name/err/results");
					move("$statue_dir/".$hash_wait_id{$thread_id},"$prog_dir/results/$name/err");
					move("$script_dir/".$hash_wait_id{$thread_id},"$prog_dir/results/$name/err/scripts");
					my $del_jobs = del_job_num($hash_wait_id{$thread_id},\%hash_task) if !$silent;
					show_process_err($hash_wait_id{$thread_id},$del_jobs,\$complete_job_num,\$total_job_num) if !$silent;
				}
				delete $hash_running{$thread_id};
				delete $hash_wait{$hash_wait_id{$thread_id}};
				delete $hash_wait_id{$thread_id};
				delete $hash_id_time{$thread_id};
			}
		}
	}
	
	sleep($sleep_time);
	
	
	if (!$silent && $complete_job_num > $complete_job_num_old){
		$complete_job_num_old = $complete_job_num ; 
		show_out_files_progress($complete_job_num,$total_job_num);
	}
	
	opendir(DIR_S,$statue_dir);
	@statue_files = readdir(DIR_S);
	closedir DIR_S;
	
	if (-f "pml_theads_err.log"){
		die 'Errors exceed limitations 100 times, PML stoped.'."\n";
	}
}

#join the last threads
while (my @threads = threads->list(threads::all)){
	for my $thread(@threads){
		if($thread->is_joinable()){
			$thread->join();
		}
	}
}

#generate the output files
analysis_out_files();

