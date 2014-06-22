package pml::job;
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
use Scalar::Util qw(looks_like_number);
use Archive::Tar;
use Cwd;

require Exporter;
use vars qw($VERSION @ISA @EXPORT);
our @ISA = qw(Exporter);
our $VERSION = '1.00';
our @EXPORT = qw(get_train_test_list print_one_fold data_for_tt job_creator_desktop job_execute_desktop
	 file_process_out randperm analysis_data_j init_pml_job job_creator_server data_for_independent); 

our $boinc_appname_single = 'weka_single';
our $boinc_appname_multi = 'weka_muti';
our $boinc_appname_single_3rd = '3rd_single';
our $boinc_appname_multi_3rd = '3rd_muti';
our $boinc_appname_tar = 'pml_tar';

our $pml_data_path;
our $results_path;
our $pml_err_path;
our $statue_dir;
our $task_tar_num;
our $task_devide_num;
our $boinc_option = '';

#*******************************************************************
#
# Function Name: init_pml_job()
#
# Description: 
#		Initialize some global variables for this module
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

sub init_pml_job{
	our $pml_data_path = "$main::prog_dir/results/$main::name/data";
	our $results_path = "sample_results";
	our $pml_err_path = "$main::prog_dir/results/$main::name/err";
	our $statue_dir = "$main::prog_dir/results/$main::name/status"; 
	
	our $task_tar_num = $main::task_tar_num;#The compress number of tasks
	our $task_devide_num = $main::task_devide_num;#The estimated devide number
	our $boinc_option = join " ",('',@main::boinc_option) if @main::boinc_option;
}


#*******************************************************************
#
# Function Name: job_creator_server()
#
# Description: 
#		Create the task for PML-server by scaning the status folder
#		This creator could compress 1 or more tasks as one unit to execute
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

sub job_creator_server{
		
	#Scan the statue folder, select the statue files which valued as 1
	our $statue_dir;
	opendir DIR_S,$statue_dir;
	my @statue_files = readdir DIR_S;
	#@statue_files = grep{$_ ne '.' && $_ ne '..'}@statue_files;
	closedir DIR_S;
	#select
	@statue_files = grep{
		if($_ ne '.' and $_ ne '..'){
			open FID,"$statue_dir/$_";
			my $line = <FID>;
			close FID;
			if ($line =~ /^1/){
				1;
			}
			else{
				0;
			}
		}
		else{
			0;
		}
	}@statue_files;
	
	#Analysis the number of selected files and decide the size of the compress file
	my $total_task_num = scalar @statue_files;
	
	our $task_tar_num;#The compress number of tasks
	our $task_devide_num;#The estimated devide number
	
	#Get the number of tasks that will be comperssed into a .tgz file
	my $per_tar_num = int($total_task_num / $task_devide_num);
	$per_tar_num = 1 if $per_tar_num < 1;
	$per_tar_num = $task_tar_num if $per_tar_num > $task_tar_num;
	
	$per_tar_num--;
	#Begin to compress..
	#Create file index
	my %hash_tar_file;#$hash_tar_file{'file_name'} = 'rename';
	my $file_count = 0;#Switch to tar the files
	my $file_count_all = 0;
	my @tasks_log;
	for (@statue_files){
		my $file_name = $_;
		my $retry_count = '';
		push @tasks_log,$file_name;
		#$folder_name is the name contains the '_retry*' 
		my $folder_name = $file_name;
		if ($file_name =~ /_retry(\d+)$/){
			$retry_count = $1;
			$file_name =~ s/_retry\d+$//;		
		}
		#check the type of the task, is with weka, or is for modeling
		my ($isweka,$istt) = sfile_analysis($file_name);
		#Index of the data file(s)
		if ($file_name =~ /independent$/){
			my @names = split(/_/,$file_name);
			my @tt_p = grep{$names[$_] eq 'tt'}(0..$#names);
			splice(@names,$tt_p[0],3);
			my $train_name = join('_',@names) . '.arff';
			my $test_name = join('_',(@names,'independent_test.arff'));
			$hash_tar_file{ "$folder_name/train.arff" } = $main::prog_dir . "/results/$main::name" . "/data/$train_name";
			$hash_tar_file{ "$folder_name/test.arff" } = $main::prog_dir . "/results/$main::name" . "/data/$test_name";
		}
		elsif ($istt){
			my @names = split(/_/,$file_name);
			my @tt_p = grep{$names[$_] eq 'tt'}(0..$#names);
			splice(@names,$tt_p[0],2);
			my $train_name = join('_',(@names,'train.arff'));
			my $test_name = join('_',(@names,'test.arff'));
			$hash_tar_file{ "$folder_name/train.arff" } = $main::prog_dir . "/results/$main::name" . "/data/$train_name";
			$hash_tar_file{ "$folder_name/test.arff" } = $main::prog_dir . "/results/$main::name" . "/data/$test_name";
		}
		else{
			my $file_name_s = $file_name;
			$file_name_s =~ s/^$main::name//s;$file_name_s =~ s/^_//;
			my @elements = split(/_/,$file_name_s);
			my @elements_t = grep{$_ =~ m/^[cft]/}@elements;
			my $isclu; #Is for cluster
			#$isclu = 1 if pop(@elements_t) eq 'clu';
			$isclu = 1 if $main::cluster_train_file;
			@elements_t = grep{$elements[$_] =~ m/^[cft]/}(0..$#elements);	
			@elements = (@elements[0..$elements_t[$#elements_t]-1]);
			my $previous_name = join('_',($main::name,@elements));			
			my $data_name = $previous_name . '.arff';
			if ($isclu){
				$hash_tar_file{"$folder_name/train.arff"} = $main::cluster_train_file;
				$hash_tar_file{"$folder_name/test.arff"} = $main::prog_dir . "/results/$main::name" . "/data/$data_name";
			}
			else{
				$hash_tar_file{"$folder_name/data.arff"} = $main::prog_dir . "/results/$main::name" . "/data/$data_name";
			}
		}
		#Index of the script and prop file
		if ($isweka){
			$hash_tar_file{"$folder_name/script"} = $main::prog_dir . "/results/$main::name" . "/scripts/$file_name";
		}
		else{
			$hash_tar_file{"$folder_name/files.tgz"} = $main::prog_dir . "/results/$main::name" . "/scripts/$file_name";
		}
		$hash_tar_file{"$folder_name/step_prop"} = $main::prog_dir . "/results/$main::name" . "/stepprops/$file_name";
		
#		#Change the statue
#		open(FID_S,">$statue_dir/$file_name");
#		print FID_S '2';
#		close FID_S;

		#Compress the files and create a boinc work
		$file_count++;
		$file_count_all++;
		if ($file_count > $per_tar_num || $file_count_all == $total_task_num){
			#The input name = experiment name + '_PML_tar_package_' + $task_create_count + .tgz
			my $path_name = $main::name . '_PML_tar_package_' . $main::task_create_count . '.tgz';
			$main::task_create_count++;
			my $path = get_boinc_path($path_name);
			compress_tasks(\%hash_tar_file , $path);
			my $iscreated = create_boinc_wu($path_name);#return 0 means successful
			if (!$iscreated){
				#Change the statue
				map{
					open(FID_S,">$statue_dir/$_");
					print FID_S '2';
					close FID_S;
				}@tasks_log;
				
				#Add info to log files
				open(FID_log,">>$main::prog_dir/results/$main::name/server_wu.log");
				print FID_log $path_name,"\n";
				close FID_log;
				
				open(FID_log,">>$main::prog_dir/results/$main::name/server_detail.log");
				print FID_log $path_name," ",join(' ',@tasks_log),"\n";
				close FID_log;
				
				open(FID_log,">>$main::prog_dir/results/$main::name/server_wait.log");
				print FID_log $path_name," ",join(' ',@tasks_log),"\n";
				close FID_log;
				
				@tasks_log=();
			}
			else{
				#Do nothing, wait for next monitoring
			}
			$file_count = 0;
		}
	}
	
	
}

#*******************************************************************
#
# Function Name: get_boinc_path($file_name)
#
# Description: 
#		Get the target path of BOINC download folder for the input name
#
# Parameters:
#
# 		$file_name: The name of the file which need to be copy
#
# Return:
#
#		The path of the target folder
#
#*********************************************************************

sub get_boinc_path{
	my ($name) = @_;
	my $path = `bin/dir_hier_path $name`;
	$path =~ s/\s+$//;
	return $path;
}

#*******************************************************************
#
# Function Name: compress_tasks($hash_tar_file_p , $tar_name)
#
# Description: 
#		Compress the task files into one file
#
# Parameters:
#
# 		$hash_tar_file_p: The reference of the hash table %hash_tar_file
#		$tar_name: The name of the compressed .tgz file
#
# Return:
#
#		None
#
#*********************************************************************

sub compress_tasks{	
	my ($hash_tar_file_p , $tar_name) = @_;
	my @keys = keys %$hash_tar_file_p;
	my $tar_tasks = Archive::Tar->new;
	#$tar_tasks->add_files(@keys);
	map{
		my $r_n = $_;
		my $n = $$hash_tar_file_p{$_};
		$n =~ s/^\.\///;
		$tar_tasks->add_files($n);
		$tar_tasks->rename($n , $r_n);
		delete $$hash_tar_file_p{$r_n};
	}@keys;
	$tar_tasks->write($tar_name , $main::compress_level);
}

#*******************************************************************
#
# Function Name: create_boinc_wu($file_name)
#
# Description: 
#		Create a boinc workunit by cmd interface
#
# Parameters:
#
# 		$file_name: The name of the compressed .tgz task file
#
# Return:
#
#		1 if successful
#
#*********************************************************************

sub create_boinc_wu{
	#Create a boinc workunit by cmd interface
	my ($file_name) = @_;
	my $boinc_appname = $boinc_appname_tar;
	our $boinc_option;
	my $cmd_line = "bin/create_work --appname $boinc_appname" . " --wu_name $file_name" . $boinc_option . " $file_name ";
	my $job_creat = system($cmd_line);
	return $job_creat;	
}

#*******************************************************************
#
# Function Name: job_creator($task_name , $wu)
#
# Description: 
#		Create computing task for PML-desktop
#
# Parameters:
#
# 		$task_name: The name of the task
#		$wu: The number of work file where the task would be executed.
#
# Return:
#
#		None
#
#*********************************************************************

sub job_creator_desktop{
	#Create computing task for PML-desktop
	my $file_name = $_[0];
	my $wu = $_[1];
	my $retry_count = '';
	if ($file_name =~ /_retry(\d+)$/){
		$retry_count = $1;
		$file_name =~ s/_retry\d+$//;		
	}
	my ($isweka,$istt,$arg_type) = sfile_analysis($file_name);
	#start to send this task
	my $job_created;
	
	if ($file_name =~ /independent$/){
		my @names = split(/_/,$file_name);
		my @tt_p = grep{$names[$_] eq 'tt'}(0..$#names);
		splice(@names,$tt_p[0],3);
		my $train_name = join('_',@names) . '.arff';
		my $test_name = join('_',(@names,'independent_test.arff'));
		copy( "$main::prog_dir/results/$main::name/data/$train_name" , "$main::prog_dir/wus/wu$wu/train.arff");	
		copy( "$main::prog_dir/results/$main::name/data/$test_name" , "$main::prog_dir/wus/wu$wu/test.arff");	
		#link( "$main::prog_dir/results/$main::name/data/$train_name" , "$main::prog_dir/wus/wu$wu/train.arff");
		#link( "$main::prog_dir/results/$main::name/data/$test_name" , "$main::prog_dir/wus/wu$wu/test.arff");	
	}
	elsif ($istt){
		my @names = split(/_/,$file_name);
		my @tt_p = grep{$names[$_] eq 'tt'}(0..$#names);
		splice(@names,$tt_p[0],2);
		my $train_name = join('_',(@names,'train.arff'));
		copy( "$main::prog_dir/results/$main::name/data/$train_name" , "$main::prog_dir/wus/wu$wu/train.arff");
		#link( "$main::prog_dir/results/$main::name/data/$train_name" , "$main::prog_dir/wus/wu$wu/train.arff");	
		my $test_name = join('_',(@names,'test.arff'));
		copy( "$main::prog_dir/results/$main::name/data/$test_name" , "$main::prog_dir/wus/wu$wu/test.arff");	
		#link( "$main::prog_dir/results/$main::name/data/$test_name" , "$main::prog_dir/wus/wu$wu/test.arff");
	}
	else{
		my $file_name_s = $file_name;
		$file_name_s =~ s/^$main::name//s;$file_name_s =~ s/^_//;
		my @elements = split(/_/,$file_name_s);
		my @elements_t = grep{$_ =~ m/^[cft]/}@elements;
		my $isclu; 
		$isclu = 1 if pop(@elements_t) eq 'clu';
		@elements_t = grep{$elements[$_] =~ m/^[cft]/}(0..$#elements);	
		@elements = (@elements[0..$elements_t[$#elements_t]-1]);
		my $previous_name = join('_',($main::name,@elements));
		my $data_name = $previous_name . '.arff';
		copy( "$main::prog_dir/results/$main::name/data/$data_name" , "$main::prog_dir/wus/wu$wu/data.arff");
		#link( "$main::prog_dir/results/$main::name/data/$data_name" , "$main::prog_dir/wus/wu$wu/data.arff");
		
	}
	if ($isweka){
		copy( "$main::prog_dir/results/$main::name/scripts/$file_name" , "$main::prog_dir/wus/wu$wu/script")
		#link( "$main::prog_dir/results/$main::name/scripts/$file_name" , "$main::prog_dir/wus/wu$wu/script")
	}
	else{
		copy( "$main::prog_dir/results/$main::name/scripts/$file_name" , "$main::prog_dir/wus/wu$wu/files.tgz");
		#link( "$main::prog_dir/results/$main::name/scripts/$file_name" , "$main::prog_dir/wus/wu$wu/files.tgz");
	}
	copy("$main::prog_dir/results/$main::name/stepprops/$file_name" , "$main::prog_dir/wus/wu$wu/step_prop");
	copy("$main::prog_dir/src/processor_single.pl" , "$main::prog_dir/wus/wu$wu/pml_run.pl");
	#link("$main::prog_dir/results/$main::name/stepprops/$file_name" , "$main::prog_dir/wus/wu$wu/step_prop");
	#link("$main::prog_dir/src/processor_single.pl" , "$main::prog_dir/wus/wu$wu/pml_run.pl");
	
	#Copy librarys if needed
	if ($isweka){		
		copy("$main::prog_dir/lib/weka.jar" , "$main::prog_dir/wus/wu$wu/weka.jar");
		#link "$main::prog_dir/lib/weka.jar" , "$main::prog_dir/wus/wu$wu/weka.jar";
	}
	else{
		#Get the platform
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
		if ($arg_type eq 'waffles'){
			my @target_names;
			if ($istt){
				@target_names = ('waffles_learn');
				map{$_ .= '.exe'}@target_names if $system eq 'win';
				copy("$main::prog_dir/lib/$system" . '_' . "$systype/waffles_learn.exe"  , "$main::prog_dir/wus/wu$wu/waffles_learn.exe");
			}
			else{
				@target_names = ('waffles_cluster' , 'waffles_dimred');
				map{$_ .= '.exe'}@target_names if $system eq 'win';
			}
			map{
				copy("$main::prog_dir/lib/$system" . '_' . "$systype/$_"  , "$main::prog_dir/wus/wu$wu/$_");
				#link("$main::prog_dir/lib/$system" . '_' . "$systype/$_"  , "$main::prog_dir/wus/wu$wu/$_");
			}@target_names;
		}
	}
}

#*******************************************************************
#
# Function Name: job_execute_desktop($wu , $task_name , $main_path)
#
# Description: 
#		Execute the created task for PML-desktop,
#		and copy the output file to the specified folder.
#		Then clean the files in the work folder.
#
# Parameters:
#
#		$wu: The number of work file where the task would be executed.
# 		$task_name: The name of the task
#		$main_path: The output file of this task would be move to $main_path/sample_result.
#
# Return:
#
#		None
#
#*********************************************************************

sub job_execute_desktop{
	my ($wu , $name , $prog_dir) = @_;
	@_ = (); #avoid leaking
	$SIG{'KILL'} = sub { 
			threads->exit(); 
		};
	my $retry_count;
	my $retry_limit = 100;
	my $wu_dir = "$prog_dir/wus/wu" . $wu ;
	my $sys = system("perl $prog_dir/wus/run" . $wu . ".pl $wu $name $prog_dir"); 
	while($sys != 0){
		$retry_count++;
		sleep 1;
		#print "retry $name in wu$wu \n";
		if ($retry_limit < $retry_count){
			open FID_err,'>pml_theads_err.log';
			print FID_err "retry $name in wu$wu \n";
			close FID_err;
			die "retry $name in wu$wu \n";
		}
		$sys = system("perl $prog_dir/wus/run" . $wu . ".pl $wu $name $prog_dir"); 
	}
	#print "\n 1 $name \n";
	while (!-f "./sample_results/$name"){
		$retry_count++;
		if (-f "$wu_dir/out.txt.arff"){
			while(!copy("$wu_dir/out.txt.arff","./sample_results/$name")){
				$retry_count++;
				sleep 1;
				#print "retry copy wu$wu/out.txt.arff to $name \n";
				if ($retry_limit < $retry_count){
					open FID_err,'>pml_theads_err.log';
					print FID_err "retry copy wu$wu/out.txt.arff to $name \n";
					close FID_err;
					die "retry copy wu$wu/out.txt.arff to $name \n";
				}
			}
		}
		elsif(-f "$wu_dir/out.txt.pre"){
			while(!copy("$wu_dir/out.txt.pre","./sample_results/$name")){
				$retry_count++;
				sleep 1;
				#print "retry copy wu$wu/out.txt.pre to $name \n";
				if ($retry_limit < $retry_count){
					open FID_err,'>pml_theads_err.log';
					print FID_err "retry copy wu$wu/out.txt.pre to $name \n";
					close FID_err;
					die "retry copy wu$wu/out.txt.arff to $name \n";
				}
			}
		}
		else{
			while(!open FID_empty,">./sample_results/$name"){
				$retry_count++;
				sleep 1;
				#print "retry creat empty file of $name in wu$wu \n";
				if ($retry_limit < $retry_count){
					open FID_err,'>pml_theads_err.log';
					print FID_err "retry creat empty file of $name in wu$wu \n";
					close FID_err;
					die "retry creat empty file of $name in wu$wu \n";
				}
			}
			close FID_empty;
		}
		if ($retry_limit < $retry_count){
			open FID_err,'>pml_theads_err.log';
			print FID_err "retry copy wu$wu/out.txt.arff to $name \n";
			close FID_err;
			die "retry copy wu$wu/out.txt.arff to $name \n";
		}
	}
	
	while(!open(FID_fin,">./sample_results/$name".'_finish')){
		$retry_count++;
		sleep 1;
		if ($retry_limit < $retry_count){
			open FID_err,'>pml_theads_err.log';
			print FID_err "retry copy wu$wu/out.txt.pre to $name \n";
			close FID_err;
			die "retry copy wu$wu/out.txt.arff to $name \n";
		}
	}
	close FID_fin;
	#print "\n 2 $name \n";
	#clean wu
	my $rmdir_root = $wu_dir;
	
	while(!opendir(DIR,$rmdir_root)){
		$retry_count++;
		sleep 1;
		if ($retry_limit < $retry_count){
			open FID_err,'>pml_theads_err.log';
			print FID_err "retry copy wu$wu/out.txt.pre to $name \n";
			close FID_err;
			die "retry copy wu$wu/out.txt.arff to $name \n";
		}
	}
	#print "\n 2.1 $name \n";
	my @files = readdir DIR;
	closedir DIR;
	@files = grep{$_ ne '.' && $_ ne '..'}@files;
	map{$_ = $rmdir_root . '/' .$_}@files;
	while ($#files > -1){
		my $file = $files[$#files];
		if (-f $file){
			unlink $file;
			pop @files;
		}
		elsif(-d $file){
			#print "2.2 $name $file\n";
			while(!opendir(SUBDIR,$file)){
				$retry_count++;
				#print "2.2.1 $name open $file\n";
				sleep 1;
				if ($retry_limit < $retry_count){
					open FID_err,'>pml_theads_err.log';
					print FID_err "retry copy wu$wu/out.txt.pre to $name \n";
					close FID_err;
					die "retry copy wu$wu/out.txt.arff to $name \n";
				}
			}
			my @subfiles = readdir(SUBDIR);
			closedir SUBDIR;
			@subfiles = grep{$_ ne '.' && $_ ne '..'}@subfiles;
			map{$_ = $file . '/' .$_}@subfiles;
			if ($#subfiles > -1){
				push @files,@subfiles;
				#print "2.3 $name $file\n"
			}
			else{
				rmdir $file;
				pop @files;
			}
		}
	}
	#print "\n 3 $name \n";
}

#*******************************************************************
#
# Function Name: sfile_analysis($task_name)
#
# Description: 
#		Analysis the type of the task.
#
# Parameters:
#
# 		$task_name: The name of the task
#
# Return:
#
#		ARRAY with two element:
#		$isweka: Whether the task would executed with weka. (1 or 0)
#		$istt: Whether the task would model data. (1 or 0)
#
#*********************************************************************

sub sfile_analysis{
	#Analyze the type of the task.
	my $arg_num, my $step;
	my $file_name = $_[0];
	my $file_name_s = $file_name;
	$file_name_s =~ s/^$main::name//s;$file_name_s =~ s/^_//;
	my @elements = split(/_/,$file_name_s);	
	my @elements_t = grep{$_ =~ m/^[cft]/}@elements;
	$step = $elements_t[$#elements_t];
	my @last_position = grep{$elements[$_] eq $step}(0..$#elements);
	$elements[$last_position[$#last_position] + 1] =~ m/^(\d+)/;
	$arg_num = $1;
	my $istt = 0;
	if ($step eq 'tt'){$istt = 1;}
	$step =~ s/clu/cluster_arg/;
	$step =~ s/fea/feature_select_arg/;
	$step =~ s/tt/tt_arg/;
	#find related line in the input file
	open(FID,$ARGV[0]);
	my $line, my @args;
	while($line = <FID>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}		
		if ($line =~ m/^$step\s*=/is){
			$line =~ m/[^=]+=\s*([^\n]+)/;
			@args = split(/,/,$1);
		}
	}
	close FID;
	
	#judge the type in the config file
	my $isweka = 0;
	my $arg_type = '';
	if ($step =~m/^clu/i){open(FID_A,"$main::prog_dir/config/cluster");}
	elsif ($step =~m/^fea/i){open(FID_A,"$main::prog_dir/config/feature");}
	elsif ($step =~m/^tt/i){open(FID_A,"$main::prog_dir/config/traintest");}
	while ($line = <FID_A>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^(\d+)\.(\w+)\s+([^\n]+)/){
			if ($1 == $args[$arg_num]){
				$arg_type = $2;
				if ($arg_type eq 'weka'){$isweka = 1;}
			}
		}
	} 
	return ($isweka , $istt , $arg_type);
}

#*******************************************************************
#
# Function Name: file_process_out( $task_name, @steps)
#
# Description: 
#		Analyze the output file of a finished task, 
#		then decide the mark of the task as complete or error.
#		For completing tasks, generate the related
#		 n-fold data files if needed.
#
# Parameters:
#
# 		$task_name: The name of the finished task.
#		@steps: The sequence of the process. Like: (¡®clu¡¯ , ¡®fea¡¯ , ¡®tt¡¯)
#
# Return:
#
#		0 if the task marked as complete, 1 if not.
#
#*********************************************************************

sub file_process_out{	
	my ($script_name,@steps) = @_;
	my $file_name_s = $script_name;
	$file_name_s =~ s/^$main::name//s;$file_name_s =~ s/^_//;
	my @elements = split(/_/,$file_name_s);
	my $out_number = $elements[$#elements];	
	#escape the tasks whose name with all or nr
	my @elements_t = grep{$_ =~ m/^[cft]/}@elements;

	my $step = $elements_t[$#elements_t];
	
	#get the name of the  data file
	@elements_t = grep{$elements[$_] =~ m/^[cft]/}(0..$#elements);
	
	@elements = (@elements[0..$elements_t[$#elements_t]-1]);
	my $previous_name = join('_',($main::name,@elements));
	
	#Generate the .info files
	my $data_info_name = $previous_name . '.info';
	my $data_info_name_path = "$pml_data_path/$data_info_name";
	my $org_name_path = "$pml_data_path/$previous_name".'.arff';
	if (!-e $data_info_name_path){
		analysis_data($org_name_path,$data_info_name_path);
		if ($step eq 'tt'){
			$previous_name =~ s/test$/train/;
			$data_info_name_path = "$pml_data_path/$data_info_name";
			$org_name_path = "$pml_data_path/$previous_name".'.arff';
			analysis_data($org_name_path,$data_info_name_path) if !-e $data_info_name_path;
		}
	}
	
	#Check whether the data file FORMAT is ARFF, if not, return with error 
	#skip when step is tt
	my $isprocessed;
	if ($step ne 'tt'){
		if (isarff("$results_path/$script_name")){
			my $retry_count = 0;
			while (-f "$pml_data_path/$script_name" . '.arff' || -s "$results_path/$script_name" != -s "$pml_data_path/$script_name" . '.arff'){
				copy("$results_path/$script_name" ,  "$pml_data_path/$script_name" . '.arff');
				die 'retry times exceed 1000 times' if ++$retry_count > 1000;
				sleep 1 if $retry_count > 1; 
			}
			#move("$results_path/$script_name" , "$pml_data_path/$script_name" . '.arff');
			unlink "$results_path/$script_name";
			$isprocessed = 1;
		}
		else{
			$isprocessed = 0;
			return $isprocessed;
		}
	}
	else {
		$isprocessed = 1;
	}
	
	
	#If the next step is tt, generate the train/test data files
	my @step_position, my $next_step;
	if ($step ne 'tt' && $isprocessed){
		@step_position = grep{$steps[$_] eq $step}(0..$#steps);
		$next_step = $steps[$step_position[$#step_position] + 1];
		if ($next_step eq 'tt'){
			data_for_tt($script_name);
			data_for_independent($script_name) if $main::independent_data;
		}
			
	}
	return $isprocessed;
}

#*******************************************************************
#
# Function Name: isarff( $file_name)
#
# Description: 
#		Judge if the data file is ARFF format.
#
# Parameters:
#
# 		$file_name: The name of the data file.
#
# Return:
#
#		1 if true, 0 if false
#
#*********************************************************************

sub isarff{
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
	
	if (!$instance_out || $instance_out <= 0 || !$attribute_out || $attribute_out <= 0){
		$isarff = 0;
	}	
	return $isarff;
}

#*******************************************************************
#
# Function Name: process_clu($out_name , $org_name , $out_prop , $seed)
#
# Description: 
#		Reduce the dimension of the instances.
#		The instanced would be reduced by the proportion of the classes. 
#		For example, if a data has 3 classes and the instances are 10, 20
#		 and 30, the proportion is 0.1 (10$), then the output data would 
#		contain the instances 1, 2 and 3 for related classes.
#		Besides, if $out_prop is more than 1, PML would calculate the 
#		proportion through dividing the $out_prop by the number of instance
#		 of the original data.
#
# Parameters:
#
# 		$out_name: The name of output data file
#		$org_name: The name of the data file which would be clustered.
#		$out_prop: The proportion of the instances of the output file
#		$seed: Random seed
#
# Return:
#
#		None
#
#*********************************************************************

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
			#a simple format for 3rd-party program output template
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

#*******************************************************************
#
# Function Name: find_position($val , @arr)
#
# Description: 
#		Get the position of specified value in the related ARRAY.
#
# Parameters:
#
# 		$val: The value need to be located
#		@arr: The ARRAY that $val in.
#
# Return:
#
#		The first position in the ARRAY if the value is located, or return -1.
#
#*********************************************************************

sub find_position{
	#Get the position of specified value in the related ARRAY.
	my ($find_val,@find) = @_;
	my $out = -1;
	my @position = grep{$find[$_] eq $find_val}(0..$#find);
	if(@position){$out = $position[0]};
	return($out);
}

#*******************************************************************
#
# Function Name: analysis_data($input_name , $output_name)
#
# Description: 
#		The same as the analysis_data in pml::init but this function 
#		could return the classes if the data is for classify.
#
# Parameters:
#
# 		$input_name: The name of the input file
#		$output_name: The name of the output file
#
# Return:
#
#		An ARRAY, the first 4 elements are:
#		Number of instances, number of attributes, if has missed value, is for classify
#		The rest elements are the classes of the data if the data is for classify.
#
#*********************************************************************

sub analysis_data{
	#The same as the analysis_data in pml::init, 
	#but this function could return the classes if the data is for classifying.
	my ($data_name_path , $out_data_path) = @_;
	
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

sub analysis_data_j{
	return analysis_data(@_);
}

#*******************************************************************
#
# Function Name: randperm($length , $seed)
#
# Description: 
#		Generate the pseudorandom sequence from 1 to $length.
#
# Parameters:
#
# 		$length: The length of the rand numbers.
#		$seed: The random seed. Default is 1
#
# Return:
#
#		An ARRAY with the random numbers.
#
#*********************************************************************

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

#*******************************************************************
#
# Function Name: get_pca(\@attributes_name,\@eigen_m,\%hash_var_names,@input_attribute)
#
# Description: 
#		Calculate the principle components of the related attribute through the use of Eigen matrix.
#
# Parameters:
#
# 		@attributes_name: The names of the attributes in the data
#		@eigen_m: Eigen matrix (2_dimention ARRAY)
#		%hash_var_names: The reference from the names of attributes to the related Eigen vectors.
#		@input_attribute: The attribute in the original data.
#
# Return:
#
#		ARRAY with principle components
#
#*********************************************************************

sub get_pca{
	#get the deatail when use PCA
	my ($attributes_name_l,$eigen_m_l,$hash_var_names_l,@sub_att) = @_;
	my ($i,$j,$k);
	my @out;
	
	for $i (0..$#{$$eigen_m_l[0]}){
		my $each_pca = 0;
		for $j (0..$#sub_att - 1){
			if (looks_like_number($sub_att[$j])){
				$each_pca += $sub_att[$j] * $$eigen_m_l[$$hash_var_names_l{$$attributes_name_l[$j]}][$i];
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

#*******************************************************************
#
# Function Name: get_lsa(\@lsa_vector_files , $label)
#
# Description: 
#		Get an instance with the values from the output files of latent semantic analysis
#
# Parameters:
#
# 		@lsa_vector_files: The files contain the lsa vectors generated by weka
#		$labes: The label with the related line.
#
# Return:
#
#		ARRAY of values for an instance
#
#*********************************************************************

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

#*******************************************************************
#
# Function Name: process_fea($out_name , $org_name , $out_num , $nfold_threshold)
#
# Description: 
#		Reduce the dimension of the variables (features).
#		This function will detected the output file and decide the way of
#		dimension reduction for different types of variable selection methods
#
# Parameters:
#
# 		$out_name: The name of output data file
#		$org_name: The name of the data file which would reduce variables.
#		$out_num: The number of variables after variable selection.
#		$nfold_threshold: The threshold in selecting variables (only valid in n-fold selection)
#
# Return:
#
#		None
#
#*********************************************************************

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

#*******************************************************************
#
# Function Name: data_for_tt( $data_name)
#
# Description: 
#		Generate the data for n-fold cross.
#		Need the number of inner folds and outer folds
#		or each files (if provided)
#
# Parameters:
#
# 		$data_name: The name of the data file
#		
# Return:
#
#		None
#
#*********************************************************************

sub data_for_tt{
	#the name is the scriptname + _inner_*_train.arff
	
	my $outfile_name = $_[0];
	my $data_path = "$pml_data_path/$outfile_name" . '.arff';
	my $data_info_name_path = "$pml_data_path/$outfile_name" . '.info';
	my $out_data_path_old = "$pml_data_path/$outfile_name";
	
	my @data_detail;
	@data_detail=analysis_data($data_path,$data_info_name_path);
	my $total_it = $data_detail[0];	
	
	#confirm the number of classes and if the data is for regress 
	my %hash_label_num,	my $data_switch, my $is4class = $data_detail[3];
	my $is4class_old = $is4class;
	if ($is4class){
		%hash_label_num = map{$_,0}@data_detail[4..$#data_detail];
		open(FID_data,$data_path);
		while (my $line = <FID_data>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line =~ /^\@data/i){
				$data_switch++;
			}
			elsif($line =~ /^[^\n]/ && $data_switch){
				$line =~ s/\n$//;
				my $label = pop @{[split /,/,$line]};
				$hash_label_num{$label}++ if exists $hash_label_num{$label};
			}
			elsif($line =~ /^%/){
				$data_switch = 0;
			}
		}
		close FID_data;
	}
	#The number of instance of each fold
	my $inner_fold = $main::inner_folds;
	my $outer_fold = $main::outer_folds;
	my @each_fold_out ;	my @each_fold_in ;
	if ($is4class){
		for my $each_label_num(0 .. $#data_detail - 4){
			$each_fold_out[$each_label_num] = int($hash_label_num{$data_detail[$each_label_num + 4]} / $outer_fold) if $outer_fold > 0;
			$each_fold_in[$each_label_num] = int(($hash_label_num{$data_detail[$each_label_num + 4]} - $each_fold_out[$each_label_num]) / $inner_fold) if $outer_fold > 1 &&  $inner_fold > 1;
			$each_fold_in[$each_label_num] = int(($hash_label_num{$data_detail[$each_label_num + 4]}) / $inner_fold) if $outer_fold == 1 &&  $inner_fold > 1;
		}
	}
	else{
		if ($outer_fold >= 1){ 
			$each_fold_out[0] = int($total_it / $outer_fold);
			if ($inner_fold > 1){
				$each_fold_in[0] = int(($data_detail[0] - $each_fold_out[0]) / $inner_fold);
				$each_fold_in[0] = int(($data_detail[0] ) / $inner_fold) if $outer_fold == 1 ;
			}
		}
	}
	my @sequence_counter;
	$sequence_counter[0] = 0 if !$is4class || @main::outer_fold_test_files || @main::outer_fold_train_files;
	@sequence_counter = map{0}@data_detail[4..$#data_detail] if $is4class && !@main::outer_fold_test_files && !@main::outer_fold_train_files;
	my $i, my $j, my $k;
	my @rand_sequence;
	@rand_sequence = [randperm($total_it,$main::seed_outer)] if !$is4class || @main::outer_fold_test_files || @main::outer_fold_train_files;
	@rand_sequence = map{[randperm($hash_label_num{$_},$main::seed_outer)]}@data_detail[4..$#data_detail] if $is4class && !@main::outer_fold_test_files && !@main::outer_fold_train_files;
	
	for $i(0..$outer_fold - 1){
		my %train_list, my %test_list;
		my @train_test_list;
		if ($outer_fold == 1){
			copy($data_path , $out_data_path_old . '_outer_' . $i . '_train.arff');
			copy("$main::prog_dir/results/$main::name/data/" . $main::name . "_test.arff" , $out_data_path_old . '_outer_' . $i . '_test.arff');
			%train_list = map{$_ , 1}1..$data_detail[0];
		}
		else{
			(@train_test_list)=get_train_test_list($i, \@sequence_counter,\@each_fold_out,$outer_fold,\@main::outer_fold_test_files,\@main::outer_fold_train_files,\@rand_sequence,\@data_detail);
			%train_list = @{$train_test_list[0]};
			$is4class = 0 if @main::outer_fold_test_files || @main::outer_fold_train_files;
			print_one_fold($out_data_path_old,'_outer_' . $i , $is4class , \@data_detail , [@train_test_list]);
			$is4class = $is4class_old;
		}
		my @data_detail_sub = analysis_data($out_data_path_old . '_outer_' . $i . '_train.arff' , $out_data_path_old . '_outer_' . $i . '_train.info');
		analysis_data($out_data_path_old . '_outer_' . $i . '_test.arff' , $out_data_path_old . '_outer_' . $i . '_test.info');
		#generate the data files for inner folds (if needed)
		if ($inner_fold){
			my @train_list_sub, my @rand_sequence_sub, my @sequence_counter_sub;
			if ($is4class && !@main::inner_fold_test_files && !@main::inner_fold_train_files){
				for $k(0 .. $#data_detail - 4){
					if ($outer_fold == 1){@rand_sequence_sub = @rand_sequence;}
					else{
						my $sub_label = $data_detail[4+$k];
						@train_list_sub = grep{$_ =~ /^$sub_label /s}keys(%train_list);
						map{$_ =~ s/^[^ ]+ //}@train_list_sub;
						@train_list_sub = sort{$a<=>$b}@train_list_sub;
						@train_list_sub = get_train_list_for_inner($out_data_path_old . '.arff' ,
						 $sub_label , $i , $data_detail[0]) if @main::outer_fold_test_files || @main::outer_fold_train_files;
						$rand_sequence_sub[$k] = [map{$_ - 1}randperm($#train_list_sub + 1,$main::seed_inner)];
						$rand_sequence_sub[$k] = [@train_list_sub[@{$rand_sequence_sub[$k]}]];
					}
					$sequence_counter_sub[$k] = 0;
				}
			}
			else{
				@train_list_sub = sort{$a<=>$b}keys(%train_list);
				push @rand_sequence_sub,[map{$_ - 1}randperm($#train_list_sub + 1,$main::seed_inner)];
				$rand_sequence_sub[0] = [@train_list_sub[@{$rand_sequence_sub[0]}]];
				$sequence_counter_sub[0] = 0;
			}
			my $j;
			for $j(0..$inner_fold - 1){
				(@train_test_list)=get_train_test_list($j, \@sequence_counter_sub,\@each_fold_in,$inner_fold,\@main::inner_fold_test_files,\@main::inner_fold_train_files,\@rand_sequence_sub,\@data_detail,$i);
				$is4class = 0 if @main::inner_fold_test_files || @main::inner_fold_train_files;
				print_one_fold($out_data_path_old,'_inner_' . $j . '_outer_' . $i , $is4class , \@data_detail , [@train_test_list]);
				$is4class = $is4class_old;
				analysis_data($out_data_path_old . '_inner_' . $j . '_outer_' . $i . '_train.arff' , $out_data_path_old . '_inner_' . $j . '_outer_' . $i . '_train.info');
				analysis_data($out_data_path_old . '_inner_' . $j . '_outer_' . $i . '_test.arff' , $out_data_path_old . '_inner_' . $j . '_outer_' . $i . '_test.info');
			}
			
			
		}
	}
}

#*******************************************************************
#
# Function Name: data_for_independent( $outfile_name)
#
# Description: 
#		Generate the dataset for independent test
#		The training dataset is the prewierious data
#		Filter the attributes of test dataset if necessary
#
# Parameters:
#
# 		$outfile_name: The name of the output data file
#		
# Return:
#
#		None
#
#*********************************************************************

sub data_for_independent{
	#Generate the dataset for independent test
	#The training dataset is the prewierious data
	#Filter the attributes of test dataset if necessary
	my $outfile_name = $_[0];
	my $train_name = $outfile_name . '.arff';
	my $train_file = "$pml_data_path/$train_name";
	my $test_name = $outfile_name . '_independent_test.arff';
	my $test_file = $main::independent_data;
	
	#Get the attributes of the test file
	my %att_test;
	my $n = 0;
	open FID_test,$test_file;	
	while (my $line = <FID_test>){
		if ($line =~ /^\@attribute\s+(\S+)/i){			
			$att_test{$1} = $n;
			$n++;
		}
	}
	close FID_test;
	
	#Get the sequence of the attributes
	my (@att_seq , @att_train);
	my $l = 0;
	open FID_train,$train_file;	
	while (my $line = <FID_train>){
		if ($line =~ /^\@attribute\s+(\S+)/i){
			if (exists $att_test{$1}){
				push(@att_seq , $att_test{$1});
				push(@att_train , $line);
				$l++ ;
			}
		}
	}
	close FID_train;
	
#	if ($n == $l){
#		copy $test_file,"$pml_data_path/$test_name";
#	}
	if (!@att_seq){
		#Show a warning message
		print "\nWarning: The labels between the training and independent test datasets are different,\n";
		print "\n\tand the independent dataset will be used as the test data directly, please check\n";
		print "\n\tthe dimension reduction methods if some tasks failed.\n";
		copy $test_file,"$pml_data_path/$test_name";
	}
	else{
		#Rearrange the value of test dataset
		my $s = 0;
		open FID_out,">$pml_data_path/$test_name";
		open FID_test,$test_file;	
		while (my $line = <FID_test>){
			if ($line =~ /^\@attribute\s+(\S+)/i){
				#Do nothing
			}
			elsif ($line =~ /^\@data/i){
				map{
					print FID_out $_; 
				}@att_train;
				print FID_out $line;
				$s = 1;
			}
			elsif ($s == 1){
				if ($line =~ /^%/ || $line =~ /^s+$/){
					$s = 0;
					print FID_out $line;
					next;
				}
				$line =~ s/\s+$//;
				my @values = split /,/,$line;
				print FID_out join(',',@values[@att_seq]);
				print FID_out "\n";
			}
			else{
				print FID_out $line; 
			}
		}
		close FID_out;
		close FID_test;
	}
	#Make a hard link of the training data for the output analysis
	link("$pml_data_path/$train_name" , "$pml_data_path/$outfile_name" . '_independent_train.arff');
	
	analysis_data("$pml_data_path/$train_name" , "$pml_data_path/$outfile_name" . '_independent_train.info');	
	analysis_data("$pml_data_path/$test_name" , "$pml_data_path/$outfile_name" . '_independent_test.info');
}

#*******************************************************************
#
# Function Name: get_train_list_for_inner($data_name , $label , 
#			$inner_folds_count , $instance_num)
#
# Description: 
#		Generate the train list for inner fold which is related with the outer fold.
#		This function is only for the situation that the output files are generated by files 
#		but the files for inner folds need to be generated by random number.
#
# Parameters:
#
# 		$data_name: The name of output data
#		$label: Specify the label of the data.
#		$inner_folds_count: The number of the inner fold
#		$instance_num: the number of the instances.
#		
# Return:
#
#		An ARRAY with the sequence numbers for the train list
#
#*********************************************************************

sub get_train_list_for_inner{

	my ($name , $label , $i , $instance)=@_;
	my $switch;
	my @train_list_sub;
	my $fold_test_files_l = \@main::outer_fold_test_files;
	my $fold_train_files_l = \@main::outer_fold_train_files;
	my %test_list; my %train_list;
	my $line;
	
	if(@$fold_test_files_l){
		open(FID_TEST,$$fold_test_files_l[$i]);
		while($line = <FID_TEST>){
			if ($line =~ m/^\s*(\d+)/){
				map{$test_list{$_}++}split /,/,$1;
			};
		}
		close FID_TEST;
	}	
	if(@$fold_train_files_l){
		open(FID_TRAIN,$$fold_train_files_l[$i]);
		while($line = <FID_TRAIN>){
			if ($line =~ m/^\s*(\d+)/){
				map{$train_list{$_}++}split /,/,$1;
			};
		}
		close FID_TRAIN;
	}	
	#put the rest values into train list if no files specify the serial
	if(!%train_list){
		map{
			$train_list{$_}++ if !exists($test_list{$_});
		}1..$instance;
	}
	#confirm the data list
	
	my $label_count = 0; my $instance_count = 0;
	
	open(FID,$name);
	while(my $line = <FID>){
		if ($switch){
			$switch = 0 if $line =~ /^%/;
			if ($line !~ /^%/){
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				if ($line){
					$instance_count++;
					my $sub_label = pop @{[split /,/,$line]};
					if ($sub_label eq $label){
						$label_count++;
						push @train_list_sub,$label_count if exists $train_list{$instance_count};
					}
				}
			} 
		}
		$switch++ if $line =~ /^\@data/i;
	}
	close FID;
	return @train_list_sub;
}

#*******************************************************************
#
# Function Name: get_train_test_list($fold_count, \@sequence_counter, 
#			\@each_fold, $num_folds, \@fold_test_files, \@fold_train_files,
#			\@rand_sequence, \@data_detail, $outer_fold_count)
#
#
# Description: 
#		Generate the training and test sequence for specified fold of the data.
#		Note that if the data has two or more classes and @fold_test_files and
#		@fold_train_files are empty, the generated list would maintain the 
#		proportion of each class. 
#		For example, if the data has 3 classes with 20, 30 and 50 instances
#		and 10 folds would be generated. Then for each fold, the instances 
#		for each class would become 2, 3 and 5.
#
# Parameters:
#
# 		$fold_count: Specify the fold in the n-fold need to be generated.
#		@sequence_counter: Reference of the records of the start position of the data. For example, if the data has 4 class, then the @sequence_conter would be initialized with (0 , 0 , 0 , 0) and added by the instances used by each fold.
#		@each_fold: Reference of the number of instances of each classed in one fold.
#		$num_folds: The number of folds.
#		@fold_test_files: An ARRAY with the test files. This parameter is for specifying the n-fold data by users, PML would generate data by random number if @fold_test_files and @fold_train_files are empty.
#		@fold_train_files: An ARRAY with the train files. This parameter is for specifying the n-fold data by users, PML would generate data by random number if @fold_test_files and @fold_train_files are empty.
#		@rand_sequence: An pseudorandom number ARRAY generated by function randperm.
#		@data_detail: The ARRAY generated by function analysis_data_j.
#		$outer_fold_count: If the data is for inner fold, this parameter is needed to specify the related outer fold.
#		
# Return:
#
#		An ARRAY with two hash tables:
#		my @out = get_train_test_list( ¡­ );
#		my %train_list = @{$out[0]};
#		my %test_list = @{$out[1]};
#
#*********************************************************************

sub get_train_test_list{
	#Generate the training and test sequence for specified fold of the data.
	#Note that if the data has two or more classes and @fold_test_files and @fold_train_files are empty, 
	#the generated list would maintain the proportion of each class. 
	#For example, if the data has 3 classes with 20, 30 and 50 instances and 10 folds would be generated. 
	#Then for each fold, the instances for each class would become 2, 3 and 5.

	my ($i, $sequence_counter_l, $each_fold_l, $num_folds,$fold_test_files_l,$fold_train_files_l,$rand_sequence_l,$data_detail_l,$outer_fold_count) = @_;
	
	my %test_list, my %train_list;my $line;
	$outer_fold_count = 0 if !$outer_fold_count;
	#Generate the list of training or testing 
	if( @$fold_test_files_l || @$fold_train_files_l ){
		if(@$fold_test_files_l){
			open(FID_TEST,$$fold_test_files_l[$i + $outer_fold_count * $main::inner_folds]);
			while($line = <FID_TEST>){
				if ($line =~ m/^\s*(\d+)/){
					map{$test_list{$_}++}split /,/,$1;
				};
			}
			close FID_TEST;
		}	
		if(@$fold_train_files_l){
			open(FID_TRAIN,$$fold_train_files_l[$i + $outer_fold_count * $main::inner_folds]);
			while($line = <FID_TRAIN>){
				if ($line =~ m/^\s*(\d+)/){
					map{$train_list{$_}++}split /,/,$1;
				};
			}
			close FID_TRAIN;
		}	
		#if just one list is specified, the rest would be generated from the complement
		if(!%test_list){
			map{
				$test_list{$_}++ if !exists($test_list{$_});
			}@{$$rand_sequence_l[0]};
		}
		elsif(!%train_list){
			map{
				$train_list{$_}++ if !exists($test_list{$_});
			}@{$$rand_sequence_l[0]};
		}
	}
	else{
		if ($$data_detail_l[3]){
			for my $k (0..$#$data_detail_l - 4){
				if ($i == $num_folds - 1){map{$test_list{"$$data_detail_l[$k + 4] $_"}++ }@{$$rand_sequence_l[$k]}[$$sequence_counter_l[$k]..$#{$$rand_sequence_l[$k]}];}
				else{
					map{$test_list{"$$data_detail_l[$k + 4] $_"}++}@{$$rand_sequence_l[$k]}[$$sequence_counter_l[$k]..$$sequence_counter_l[$k] + $$each_fold_l[$k] - 1];
					$$sequence_counter_l[$k] = $$sequence_counter_l[$k] + $$each_fold_l[$k];
				}
				map{$train_list{"$$data_detail_l[$k + 4] $_"}++}grep{!exists($test_list{"$$data_detail_l[$k + 4] $_"})}@{$$rand_sequence_l[$k]};
			}
		}
		else{
			#test list from random number
			if ($i == $num_folds - 1){%test_list = map{$_,1}@{$$rand_sequence_l[0]}[$$sequence_counter_l[0]..$#{$$rand_sequence_l[0]}];}
			else{
				%test_list = map{$_,1}@{$$rand_sequence_l[0]}[$$sequence_counter_l[0]..$$sequence_counter_l[0] + $$each_fold_l[0] - 1];
				$$sequence_counter_l[0] = $$sequence_counter_l[0] + $$each_fold_l[0];
			}
			#train list from the rest serials
			%train_list = map{$_,1}grep{!exists($test_list{$_})}@{$$rand_sequence_l[0]};
		}
	}
	return([%train_list],[%test_list]);
}

#*******************************************************************
#
# Function Name: print_one_fold($data_org_name, $add_name, 
#			$is4class, \@data_detail, \@train_test_list)
#
#
# Description: 
#		Print the training and test data of one fold into related files.
#
# Parameters:
#
# 		$data_org_name: The name of the original data.
#		$add_name: The string needed to be add to change the $data_org_name.
#		$is4class: If the data is for classify
#		@data_detail: An ARRAY generated by the function analysis_data_j.
#		@train_test_list: An ARRAY generated by the function get_train_test_list.
#		
# Return:
#
#		None
#
#*********************************************************************

sub print_one_fold{
	#Print the training and test data of one fold into related files.
	#naming: add the _inner_*_outer_*.arff or _outer_*.arff
	my ($org_name,$add_name,$is4class,$data_detail_l) = @_[0..3];
	my %train_list = @{${$_[4]}[0]};
	my %test_list = @{${$_[4]}[1]};
	my $instance_count = 0;
	my %hash_instance_count;
	map{$hash_instance_count{$_}=0}@$data_detail_l[4..$#$data_detail_l];
	my @lines_train; my @lines_test;
	open(FID_Org, $org_name . '.arff');
	open(FID_Out_Train, '>' . $org_name . $add_name . '_train.arff');
	open(FID_Out_Test, '>' . $org_name . $add_name . '_test.arff');
	my $line, my $control = 0;
	while ($line = <FID_Org>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@data/i){
			$control = 1;
			push @lines_train,$line;
			push @lines_test,$line;
		}
		elsif($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
				push @lines_train,$line;
				push @lines_test,$line;
				next;
			}
			
			if ($is4class){
				my $label = $line;
				$label =~ s/\n$//;
				$label = pop @{[split /,/,$label]};
				$hash_instance_count{$label}++;
				if (exists($train_list{"$label $hash_instance_count{$label}"})){
					push @lines_train,$line;
				}
				elsif (exists($test_list{"$label $hash_instance_count{$label}"})){
					push @lines_test,$line;
				}
			}
			else{
				$instance_count++;
				if (exists($train_list{$instance_count})){
					push @lines_train,$line;				
				}
				elsif (exists($test_list{$instance_count})){
					push @lines_test,$line;
				}
			}
			
		}
		else{
			push @lines_train,$line;
			push @lines_test,$line;
		}
		if ($#lines_train > 500){
			print FID_Out_Train @lines_train;
			@lines_train = ();
		}
		if ($#lines_test > 500){
			print FID_Out_Test @lines_test;
			@lines_test = ();
		}
	}
	print FID_Out_Train @lines_train;
	print FID_Out_Test @lines_test;
	close FID_Out_Train;
	close FID_Out_Test;
}





1;
__END__