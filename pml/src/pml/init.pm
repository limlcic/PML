package pml::init;
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

require Exporter;
use vars qw($VERSION @ISA @EXPORT);
our @ISA = qw(Exporter);
our $VERSION = 1.00;
our @EXPORT = qw(get_split_grid reset_desktop reset_server get_threads_number creat_floders get_job_num 
	analysis_data show_detail data_copy del_job_num rmtree init_wu creat_job_clu creat_job_fea creat_job_tt server_clean 
	uncompressdir);

use warnings;
use strict;
use File::Copy;
use Archive::Tar;
use Cwd;

#Initial some hashs for task creater
our (%waffles_arg , %waffles_clu , %waffles_fea);
init_waffles_options();

#*******************************************************************
#
# Function Name: init_waffles_options( )
#
# Description: This function is for PML to modify some global parameters of waffles.
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
sub init_waffles_options{
	#This function is for PML to modify some parameters of waffles
	our (%waffles_arg , %waffles_clu , %waffles_fea);
	$waffles_arg{'waffles_cluster'} = \%waffles_clu;
	$waffles_arg{'waffles_dimred'} = \%waffles_fea;
	
	my (%waffles_breadthfirstunfolding , %waffles_isomap , %waffles_lle, %waffles_manifoldsculpting , %waffles_neropca , %waffles_pca);
	map{	$waffles_breadthfirstunfolding{$_}++	}('-seed' , '-reps');
	map{	$waffles_isomap{$_}++	}('-seed' , 'tolerant');
	map{	$waffles_lle{$_}++	}('-seed');
	map{	$waffles_manifoldsculpting{$_}++	}('-seed' , '-continue' , '-scalerate');
	map{	$waffles_neropca{$_}++	}('-seed' , '-clampbias' , '-linear');
	map{	$waffles_pca{$_}++	}('-seed' , '-roundtrip' , '-eigenvalues', '-components' , '-aboutorigin', '-modelin' , '-modelout');
		
	$waffles_fea{'breadthfirstunfolding'} = \%waffles_breadthfirstunfolding;
	$waffles_fea{'isomap'} = \%waffles_isomap;
	$waffles_fea{'lle'} = \%waffles_lle;
	$waffles_fea{'manifoldsculpting'} = \%waffles_neropca;
	$waffles_fea{'pca'} = \%waffles_pca;
	
	my (%waffles_agglomerative , %waffles_fuzzykmeans , %waffles_kmeans, %waffles_kmedoids);
	map{	$waffles_fuzzykmeans{$_}++	}('-seed' , '-reps' , '-fuzzifier');
	map{	$waffles_kmeans{$_}++	}('-seed' , '-reps' );
	map{	$waffles_agglomerative{$_}++	}('-seed' , '-reps' );
	map{	$waffles_kmedoids{$_}++	}('-seed' , '-reps' );
	
	$waffles_clu{'agglomerative'} = \%waffles_agglomerative;
	$waffles_clu{'fuzzykmeans'} = \%waffles_fuzzykmeans;
	$waffles_clu{'kmeans'} = \%waffles_kmeans;
	$waffles_clu{'kmedoids'} = \%waffles_kmedoids;
}


#*******************************************************************
#
# Function Name: analysis_data( )
#
# Description: This function is to analysis the ARFF format data, return the details..
#
# Parameters:
#
# 		$input_name: The name of the data need to be analysis.
#		$output_name: The name of the file which record the details of the file.
#
# Return:
#
#		A four elements ARRAY:
#		number of instances, number of attributes, is for classify, if have missed value
#
#*********************************************************************

sub analysis_data{
	my ($input_name , $output_name) = @_;
	my $attribute = 0;
	my $control = 0;
	my $miss = 0;
	my $instance = 0;
	my $attribute_detail;
	my $is4class;
	open(FID,"$input_name");
	open(FID_OUT,">$output_name");
	while (my $line = <FID>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^\@attribute/i && $control == 0){
			$attribute++;
			$attribute_detail = $line;
		}
		elsif ($line =~ m/^\@data/i){
			$control = 1;
			print FID_OUT "number of attribute is $attribute\n";
			if($attribute_detail =~ m/\@attribute\s+[^\s]+\s+\{([^\}]+)\}/i){
				my @classes = split(m/,/,$1);
				my $classes_num = @classes;
				$is4class = 1;
				print FID_OUT "responce data type is for classify\nhave $classes_num classes: $1\n";
			}
			else{
				$is4class = 0;
				print FID_OUT "responce data type is for regress\n";
			}
		}
		elsif ($control == 1){
			if ($line =~ m/^%/){
				$control = 0;
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
	print FID_OUT "number of instance is $instance\n";
	print FID_OUT "if exist missing data $miss\n";
	close FID;
	close FID_OUT;
	#return ($instance,$is4class);
	return($instance,$attribute,$is4class,$miss);
}

#*******************************************************************
#
# Function Name: creat_job_clu( $scriptname , $experiment_name 
#		, $max_memory , [@cluster_arg] , [@cluster_arg_grid] , [@cluster_out_instances] )
#
# Description: This function is to analysis the input of users, generate related script and status files.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@cluster_arg: Cluster methods.
#		@cluster_arg_grid: The parameter optimization information.
#		@cluster_out_instances: The instances after cluster
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_clu{
	#Compress the specified method for the next step.
	my $scriptname = $_[0];
	my $name = $_[1];
	my $max_memory = $_[2]; 
	my @cluster_arg = @{$_[3]};
	my @cluster_arg_grid = @{$_[4]};#PO will be skip if it is empty
	my @cluster_out_instances = @{$_[5]};
	my @script_line;
	my @script_line_out;
	my $line;my $i;my $j;my $k; my $l;my $s_j;
	my $sub_parm;
	my $grid_control;#PO will be skip if the value is 0
	my @each_grid;
	my $out_filename;
	my $grid_parm_num;
	
	creat_job_for_all($scriptname,'clu') if grep{$_ eq 'all'}@cluster_out_instances;
	
	
	for $i(0..$#cluster_arg){
		my @grid_parms;my @sub_grid_parms;
		my @grid_parm_sub_num;
		my $trd_control = 0;
		open(FID_ARG,"$main::prog_dir/config/cluster");
		while ($line = <FID_ARG>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line =~ m/^(\d+)\.(\w+)\s+([^\n]+)/){
				if ($1 == $cluster_arg[$i]){
					if ($2 eq 'weka'){
						@script_line = split(m/ /,$3);
					}
					else{
						$line =~ m/^(\d+)\.(\w+)\s+([^\s]+)/;					
						my $arg_name = $3;
						creat_job_clu_3rd($arg_name,$i,[@cluster_arg],[@cluster_arg_grid],[@cluster_out_instances],$scriptname,$2);
						$trd_control++;
					}
				}
			}
		}
		close FID_ARG;
		next if $trd_control;
		my @grid_position = grep{$cluster_arg_grid[$_] =~ m/^$cluster_arg[$i]/g}(0..$#cluster_arg_grid);
		if(@grid_position){
			@each_grid = split(m/ /,$cluster_arg_grid[$grid_position[0]]);
			for ($j = 1;$j <= $#each_grid;$j += 2){
				#split the parameters, for example
				#-c 1:5 => -c 1 2 3 4 5
				@grid_parms = (@grid_parms , [$each_grid[$j],alalysis_grid_parm($each_grid[$j+1])]);
				@script_line = replace_grid_parm($grid_parms[$#grid_parms][0],$grid_parms[$#grid_parms][1],@script_line);
			}
			$grid_control = 1;
		}
		else{
			#Set a switch to skip the PO
			$grid_control = 0;
		}
		if ($grid_control == 0){
			#no changed parameters
			if ($main::cluster_train_file){@script_line = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t train.arff -T test.arff -p 0',@script_line[1..$#script_line],'> out.txt');}
			else{@script_line = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t data.arff -p 0',@script_line[1..$#script_line],'> out.txt');}
			write_script_isweka($scriptname . '_clu_' . $i , 1);
			write_script_prop($scriptname . '_clu_' . $i , 'defaule');
			#begin to write scripts
			for $j(0..$#cluster_out_instances){
				if ($cluster_out_instances[$j] ne 'all'){
					$out_filename = $scriptname . '_clu_' . $i . '_' .$j;
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu',$cluster_out_instances[$j],$main::seed_clu);
					write_scripts_and_status($name,$out_filename,@script_line);
				}
			}
			
		}
		else {
			#For changed parameters, more loops are needed
			$sub_parm = -1;
			
			#Estimate the number of the tasks, make an ARRAY contain the max number for each changed parameter 
			$grid_parm_num = 1;
			for $j(0..$#grid_parms){
				$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} );
				@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} );
			}
			for $j(0..$grid_parm_num-1){
				$sub_parm++;
				@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
				write_script_isweka($scriptname . '_clu_' . $i . '.' . $sub_parm, 1);
				
				for $s_j(0..$#sub_grid_parms){
					@script_line = replace_grid_parm($grid_parms[$s_j][0],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 1],@script_line);
					write_script_prop($scriptname . '_clu_' . $i . '.' . $sub_parm, $grid_parms[$s_j][0] , $grid_parms[$s_j][$sub_grid_parms[$s_j] + 1]);
				}
				if ($main::cluster_train_file){@script_line_out = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t train.arff -T test.arff -p 0',@script_line[1..$#script_line],'> out.txt');}
				else{@script_line_out = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t data.arff -p 0',@script_line[1..$#script_line],'> out.txt');}
				
				for $k(0..$#cluster_out_instances){
					if ($cluster_out_instances[$k] ne 'all'){
						$out_filename = $scriptname . '_clu_' . $i .  '.' . $sub_parm . '_' .$k;
						print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu',$cluster_out_instances[$k],$main::seed_clu);
						write_scripts_and_status($name,$out_filename,@script_line_out);
					}
				}
				
				
			}

		}
	}
}

#*******************************************************************
#
# Function Name: creat_job_clu_3rd( $scriptname , $experiment_name 
#		, $max_memory , [@cluster_arg] , [@cluster_arg_grid] , [@cluster_out_instances] , $third_arg_type)
#
# Description: If the tasks is 3rd program which added by users, this function would be utilized.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@cluster_arg: Cluster methods.
#		@cluster_arg_grid: The parameter optimization information.
#		@cluster_out_instances: The instances after cluster
#		$third_arg_type : the type of the 3rd method, such as '3rd' , 'waffles' , etc.
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_clu_3rd{
	#Process the parameters directly on each file.
	
	my $arg_name = $_[0];
	my $i = $_[1], my $j, my $k, my $l;
	my @cluster_arg = @{$_[2]};
	my @cluster_arg_grid = @{$_[3]};#PO will be skip if it is empty
	my @cluster_out_instances = @{$_[4]};
	my $scriptname = $_[5];
	my $third_arg_type = $_[6];
	my @grid_position = grep{$cluster_arg_grid[$_] =~ m/^$cluster_arg[$i]/g}(0..$#cluster_arg_grid);
	my (@each_grid , @grid_parms,$out_filename);
	
	my $isranker;
	#judge if the method is with ranker search method
	if (-e "$main::prog_dir/config/fea/$arg_name/algprop"){
		open (FID_A,"$main::prog_dir/config/fea/$arg_name/algprop");
		while (my $line = <FID_A>){
			if ($line =~ /no\s+rank/i || $line =~ /no\s+ranker/i){
				$isranker = 0;
			}
		}
		close FID_A;
	}
	else{$isranker = 1;}
	
	
	if (@grid_position){
		#Create a temporary folder
		dircopy("$main::prog_dir/config/clu/$arg_name","$main::prog_dir/config/grid/$arg_name");
		@each_grid = split_grid(' ',$cluster_arg_grid[$grid_position[0]]);
		for (@each_grid){$_ =~ s/###//;}
		for ($j = 1;$j <= $#each_grid;$j += 5){
			#split the parameters, for example
			#-c 1:5 => -c 1 2 3 4 5
			@grid_parms = (@grid_parms , [@each_grid[$j..$j+3],alalysis_grid_parm_3rd($each_grid[$j+4])]);
		}
		
		my $sub_parm = -1;			
		my $grid_parm_num = 1;
		my @grid_parm_sub_num, my @sub_grid_parms, my $s_j;		
		for $j(0..$#grid_parms){
			$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} - 3);
			@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} - 3);
		}
		for $j(0..$grid_parm_num-1){
			$sub_parm++;
			@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
			
			write_script_isweka($scriptname . '_clu_' . $i .  '.' . $sub_parm, 0);
			my %changed_files;
			map{
				$changed_files{${$grid_parms[$_]}[0]}=1;
			}0..$#sub_grid_parms;
			map{
				recover_file('clu',$arg_name,$_);
			}keys(%changed_files);
			for $s_j(0..$#sub_grid_parms){
				replace_grid_parm_3rd('grid',$arg_name,@{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
				write_script_prop($scriptname . '_clu_' . $i .  '.' . $sub_parm, @{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
			}
			if (!$isranker){
				$out_filename = $scriptname . '_clu_' . $i .  '.' . $sub_parm . '_nr';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu','nr',$main::seed_clu);
				compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
				copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");
				write_status($out_filename,'1');
			}
			else{
				for $k(0..$#cluster_out_instances){
					if ($cluster_out_instances[$k] ne 'all'){
						$out_filename = $scriptname . '_clu_' . $i .  '.' . $sub_parm . '_' .$k;
						modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';
						print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu',$cluster_out_instances[$k],$main::seed_clu);				
						compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
						copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
						write_status($out_filename,'1');
					}
				}
			}
			detail_back("$main::prog_dir/config/clu/$arg_name","$main::prog_dir/config/grid/$arg_name",\@grid_parms);
			unlink("$main::prog_dir/config/grid/$arg_name" . '.tgz');
		}
		rmtree("$main::prog_dir/config/grid/$arg_name");
	}
	else{
		write_script_isweka($scriptname . '_clu_' . $i, 0);
		write_script_prop($scriptname . '_clu_' . $i, 'default');
		#Add some action for waffles
		my $arg_type = 'clu';
		if ($third_arg_type eq 'waffles'){
			dircopy("$main::prog_dir/config/clu/$arg_name","$main::prog_dir/config/grid/$arg_name");
			$arg_type = 'grid';
		}
		if (!$isranker){
			$out_filename = $scriptname . '_clu_' . $i . '_nr';
			print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu','nr',$main::seed_clu);
			compress_dir($arg_name,$arg_type) if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
			copy("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
			write_status($out_filename,'1');
			unlink "$main::prog_dir/config/fea/$arg_name/prop";
		}
		else{
			for $j(0..$#cluster_out_instances){
				if ($cluster_out_instances[$j] ne 'all'){
					$out_filename = $scriptname . '_clu_' . $i . '_' .$j;
					modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';				
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'clu',$cluster_out_instances[$j],$main::seed_clu);
					compress_dir($arg_name,$arg_type) if !-e "$main::prog_dir/config/$arg_type/$arg_name" . '.tgz';
					copy("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
					write_status($out_filename,'1');
					unlink "$main::prog_dir/config/$arg_type/$arg_name/prop";
				}
			}
		}
		rmtree("$main::prog_dir/config/grid/$arg_name") if $third_arg_type eq 'waffles';
		unlink("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz');
	}
}

#*******************************************************************
#
# Function Name: creat_job_fea( $scriptname , $experiment_name 
#		, $max_memory , [@feature_select_arg] , [@feature_arg_grid] , [@feature_out_features] )
#
# Description: This function is to analysis the input of users, generate related script and status files.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@feature_select_arg: Variable selection methods.
#		@feature_arg_grid: The parameter optimization information.
#		@feature_out_features: The out variables after variable selection
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_fea{
	my $scriptname = $_[0];
	my $name = $_[1];
	my $max_memory = $_[2]; 
	my @feature_select_arg = @{$_[3]};
	my @feature_arg_grid = @{$_[4]};#PO will be skip if it is empty
	my @feature_out_features = @{$_[5]};
	my @script_line;
	my @script_line_out;
	my $line;my $i;my $j;my $k; my $l;my $s_j;
	my $sub_parm;
	my $grid_control;#PO will be skip if the value is 0
	my @each_grid;
	my $out_filename;
	my $grid_parm_num;
	
	creat_job_for_all($scriptname,'fea') if grep{$_ eq 'all'}@feature_out_features;
	
	for $i(0..$#feature_select_arg){
		my @grid_parms;my @sub_grid_parms;
		my @grid_parm_sub_num;
		my $isranker = 0;
		my $trd_control = 0;
		open(FID_ARG,"$main::prog_dir/config/feature");
		while ($line = <FID_ARG>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line =~ m/^(\d+)\.(\w+)\s+([^\n]+)/){
				if ($1 == $feature_select_arg[$i]){
					if ($2 eq 'weka'){
						my $cmd_line = $3;
						$isranker = 1 if $cmd_line =~ m/Ranker/ ;
						@script_line = split(m/ /,$cmd_line);
					}
					else{
						$line =~ m/^(\d+)\.(\w+)\s+([^\s]+)/;					
						my $arg_name = $3;
						creat_job_fea_3rd($arg_name,$i,[@feature_select_arg],[@feature_arg_grid],[@feature_out_features],$scriptname,$2);
						$trd_control++;
					}
				}
			}
		}
		close FID_ARG;
		next if $trd_control;
		my @grid_position = grep{$feature_arg_grid[$_] =~ m/^$feature_select_arg[$i]/g}(0..$#feature_arg_grid);
		if(@grid_position){
			@each_grid = split(m/ /,$feature_arg_grid[$grid_position[0]]);
			for ($j = 1;$j <= $#each_grid;$j += 2){
				#split the parameters, for example
				#-c 1:5 => -c 1 2 3 4 5
				@grid_parms = (@grid_parms , [$each_grid[$j],alalysis_grid_parm($each_grid[$j+1])]);
				@script_line = replace_grid_parm($grid_parms[$#grid_parms][0],$grid_parms[$#grid_parms][1],@script_line);
			}
			$grid_control = 1;
		}
		else{
			$grid_control = 0;
		}
		if ($grid_control == 0){			
			@script_line = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-i data.arff',@script_line[1..$#script_line],'> out.txt');
			write_script_isweka($scriptname . '_fea_' . $i , 1);
			write_script_prop($scriptname . '_fea_' . $i , 'defaule');
			#begin to write scripts
			if ($isranker == 1){
				#generate tasks for ranker
				for $j(0..$#feature_out_features){
					if ($feature_out_features[$j] ne 'all'){
						$out_filename = $scriptname . '_fea_' . $i . '_' .$j;
						print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea',$feature_out_features[$j],$main::feautre_threshold);
						write_scripts_and_status($name,$out_filename,@script_line);
					}
				}
			}
			else{
				#for search method without rank, @feature_out_features would be ignord, string '_nr' would be added
				$out_filename = $scriptname . '_fea_' . $i . '_nr';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea','nr',$main::feautre_threshold);
				write_scripts_and_status($name,$out_filename,@script_line);
			}
			
		}
		else {
			#For changed parameters, more loops are needed
			$sub_parm = -1;
			
			#Estimate the number of the tasks, make an ARRAY contain the max number for each changed parameter 
			$grid_parm_num = 1;
			for $j(0..$#grid_parms){
				$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} );
				@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} )
			}
			for $j(0..$grid_parm_num-1){
				$sub_parm++;
				@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
				write_script_isweka($scriptname . '_fea_' . $i . '.' . $sub_parm, 1);
				
				for $s_j(0..$#sub_grid_parms){
					@script_line = replace_grid_parm($grid_parms[$s_j][0],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 1],@script_line);
					write_script_prop($scriptname . '_fea_' . $i . '.' . $sub_parm, $grid_parms[$s_j][0] , $grid_parms[$s_j][$sub_grid_parms[$s_j] + 1]);
				}
				@script_line_out = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-i data.arff',@script_line[1..$#script_line],'> out.txt');
				if ($isranker == 1){
					for $k(0..$#feature_out_features){
						if ($feature_out_features[$k] ne 'all'){
							$out_filename = $scriptname . '_fea_' . $i .  '.' . $sub_parm . '_' .$k;
							print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea',$feature_out_features[$k],$main::feautre_threshold);
							write_scripts_and_status($name,$out_filename,@script_line_out);
						}
					}
				}
				else{
					$out_filename = $scriptname . '_fea_' . $i .  '.' . $sub_parm . '_nr';
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea','nr',$main::feautre_threshold);
					write_scripts_and_status($name,$out_filename,@script_line_out);
				}
				
			}

		}
	}
}

#*******************************************************************
#
# Function Name: creat_job_fea( $scriptname , $experiment_name 
#		, $max_memory , [@feature_select_arg] , [@feature_arg_grid] 
#		, [@feature_out_features] , $third_arg_type)
#
# Description: If the tasks is 3rd program which added by users, this function would be utilized.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@feature_select_arg: Variable selection methods.
#		@feature_arg_grid: The parameter optimization information.
#		@feature_out_features: The out variables after variable selection
#		$third_arg_type : the type of the 3rd method, such as '3rd' , 'waffles' , etc.
#
# Return:
#
#		None
#
#*********************************************************************
sub creat_job_fea_3rd{
	#If the tasks is 3rd program which added by users, this function would be utilized.
	#Process the parameters directly on each file.
	my $arg_name = $_[0];
	my $i = $_[1], my $j, my $k, my $l;
	my @feature_select_arg = @{$_[2]};
	my @feature_arg_grid = @{$_[3]};#PO will be skip if it is empty
	my @feature_out_features = @{$_[4]};
	my $scriptname = $_[5];
	my $third_arg_type = $_[6];#3rd, waffles, or something else
	my @grid_position = grep{$feature_arg_grid[$_] =~ m/^$feature_select_arg[$i]/g}(0..$#feature_arg_grid);
	my (@each_grid , $out_filename , @grid_parms , $isranker);
	#judge if the method is with ranker search method
	if (-e "$main::prog_dir/config/fea/$arg_name/algprop"){
		open (FID_A,"$main::prog_dir/config/fea/$arg_name/algprop");
		while (my $line = <FID_A>){
			if ($line =~ /no\s+rank/i || $line =~ /no\s+ranker/i){
				$isranker = 0;
			}
		}
		close FID_A;
	}
	elsif ($third_arg_type eq 'waffles'){
		$isranker = 1;
	}
	else{$isranker = 1;}
	if (@grid_position){
		#Create a temporary folder
		dircopy("$main::prog_dir/config/fea/$arg_name","$main::prog_dir/config/grid/$arg_name");
		@each_grid = split_grid(' ',$feature_arg_grid[$grid_position[0]]);
		for (@each_grid){$_ =~ s/###//;}
		for ($j = 1;$j <= $#each_grid;$j += 5){
			#split the parameters, for example
			#-c 1:5 => -c 1 2 3 4 5
			@grid_parms = (@grid_parms , [@each_grid[$j..$j+3],alalysis_grid_parm_3rd($each_grid[$j+4])]);
		}
		my $sub_parm = -1;			
		my $grid_parm_num = 1;
		my @grid_parm_sub_num, my @sub_grid_parms, my $s_j;		
		for $j(0..$#grid_parms){
			$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} - 3);
			@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} - 3);
		}
		for $j(0..$grid_parm_num-1){
			$sub_parm++;
			@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
			
			write_script_isweka($scriptname . '_fea_' . $i .  '.' . $sub_parm, 0);
			my %changed_files;
			map{
				$changed_files{${$grid_parms[$_]}[0]}=1;
			}0..$#sub_grid_parms;
			map{
				recover_file('fea',$arg_name,$_);
			}keys(%changed_files);
			for $s_j(0..$#sub_grid_parms){
				replace_grid_parm_3rd('grid',$arg_name,@{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
				write_script_prop($scriptname . '_fea_' . $i .  '.' . $sub_parm, @{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
			}
			if (!$isranker){
				$out_filename = $scriptname . '_fea_' . $i .  '.' . $sub_parm . '_nr';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea','nr',$main::feautre_threshold);
				compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
				copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");
				write_status($out_filename,'1');
			}
			else{
				for $k(0..$#feature_out_features){
					if ($feature_out_features[$k] ne 'all'){
						$out_filename = $scriptname . '_fea_' . $i .  '.' . $sub_parm . '_' .$k;
						modify_waffles_out_num('grid',$arg_name,$feature_out_features[$k]) if $third_arg_type eq 'waffles';
						print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea',$feature_out_features[$k],$main::feautre_threshold);
						compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
						copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
						write_status($out_filename,'1');
					}
				}
			}
			detail_back("$main::prog_dir/config/fea/$arg_name","$main::prog_dir/config/grid/$arg_name",\@grid_parms);
			unlink("$main::prog_dir/config/grid/$arg_name" . '.tgz');
		}
		rmtree("$main::prog_dir/config/grid/$arg_name");
	}
	else{
		write_script_isweka($scriptname . '_fea_' . $i, 0);
		write_script_prop($scriptname . '_fea_' . $i, 'default');
		#Add some action for waffles
		my $arg_type = 'fea';
		if ($third_arg_type eq 'waffles'){
			dircopy("$main::prog_dir/config/fea/$arg_name","$main::prog_dir/config/grid/$arg_name");
			$arg_type = 'grid';
		}
		if (!$isranker){
			$out_filename = $scriptname . '_fea_' . $i . '_nr';
			print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea','nr',$main::feautre_threshold);
			compress_dir($arg_name,'fea') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
			copy("$main::prog_dir/config/fea/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
			write_status($out_filename,'1');
			unlink "$main::prog_dir/config/fea/$arg_name/prop";
		}
		else{
			for $j(0..$#feature_out_features){
				if ($feature_out_features[$j] ne 'all'){
					$out_filename = $scriptname . '_fea_' . $i . '_' .$j;
					modify_waffles_out_num('grid',$arg_name,$feature_out_features[$j]) if $third_arg_type eq 'waffles';
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'fea',$feature_out_features[$j],$main::feautre_threshold);
					compress_dir($arg_name,$arg_type) if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
					copy("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
					write_status($out_filename,'1');
					unlink "$main::prog_dir/config/$arg_type/$arg_name/prop";
				}
			}
		}
		rmtree("$main::prog_dir/config/grid/$arg_name") if $third_arg_type eq 'waffles';
		unlink("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz');
	}
}

#*******************************************************************
#
# Function Name: creat_job_tt( $scriptname , $experiment_name 
#		, $max_memory , [@tt_arg] , [@tt_arg_grid] , $inner_folds , $outer_folds  )
#
# Description: This function is to analysis the input of users, generate related script and status files.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@tt_arg: Modeling (train test) methods.
#		@tt_arg_grid: The parameter optimization information.
#		$inner_folds: The number of inner folds
#		$outer_folds: The number of outer folds
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_tt{
	my $scriptname = $_[0];
	my $name = $_[1];
	my $max_memory = $_[2]; 
	my @tt_arg = @{$_[3]};
	my @tt_arg_grid = @{$_[4]};
	my $inner_folds = $_[5] - 1;
	my $outer_folds = $_[6] - 1;
	my @script_line;
	my @script_line_out;
	my $line;my $i;my $j;my $k; my $l;my $s_j;
	my $sub_parm;
	my $grid_control;
	my @each_grid;
	my $out_filename;
	my $grid_parm_num;
	for $i(0..$#tt_arg){
		my @grid_parms;my @sub_grid_parms;
		my @grid_parm_sub_num;
		my $trd_control = 0;
		open(FID_ARG,"$main::prog_dir/config/traintest");
		while ($line = <FID_ARG>){
			if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
			if ($line =~ m/^(\d+)\.(\w+)\s+([^\n]+)/){
				if ($1 == $tt_arg[$i]){
					if ($2 eq 'weka'){
						@script_line = split(m/ /,$3);
					}
					else{
						$line =~ m/^(\d+)\.(\w+)\s+([^\s]+)/;					
						my $arg_name = $3;
						creat_job_tt_3rd($arg_name,$i,[@tt_arg],[@tt_arg_grid],$scriptname,$inner_folds,$outer_folds,$2);
						$trd_control++;
					}
				}
			}
		}
		close FID_ARG;
		next if $trd_control;
		my @grid_position = grep{$tt_arg_grid[$_] =~ m/^$tt_arg[$i]/g}(0..$#tt_arg_grid);
		if(@grid_position){
			@each_grid = split(m/ /,$tt_arg_grid[$grid_position[0]]);
			for ($j = 1;$j <= $#each_grid;$j += 2){
				#split the parameters, for example
				#-c 1:5 => -c 1 2 3 4 5
				@grid_parms = (@grid_parms , [$each_grid[$j],alalysis_grid_parm($each_grid[$j+1])]);
				@script_line = replace_grid_parm($grid_parms[$#grid_parms][0],$grid_parms[$#grid_parms][1],@script_line);
			}
			$grid_control = 1;			
		}
		else{
			$grid_control = 0;
		}
		if ($grid_control == 0){
			@script_line = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t train.arff -T test.arff -p 0',@script_line[1..$#script_line],'> out.txt');
			write_script_isweka($scriptname . '_tt_' . $i , 1);
			write_script_prop($scriptname . '_tt_' . $i , 'defaule');
			for $l(0..$outer_folds){
				if ($inner_folds){
					for $k(0..$inner_folds){
						$out_filename = $scriptname . '_tt_' . $i . '_inner_' . $k . '_outer_' .$l;
						print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
						write_scripts_and_status($name,$out_filename,@script_line);
					}
				}			
				$out_filename = $scriptname . '_tt_' . $i . '_outer_' . $l;
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
				write_scripts_and_status($name,$out_filename,@script_line);
			}
			
			#Generate tasks for independent test 
			if ($main::independent_data){
				$out_filename = $scriptname . '_tt_' . $i . '_independent';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
				write_scripts_and_status($name,$out_filename,@script_line);
			}
			
		}
		else {
			$sub_parm = -1;
			$grid_parm_num = 1;
			for $j(0..$#grid_parms){
				$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} );
				@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} )
			}
			for $j(0..$grid_parm_num-1){
				$sub_parm++;
				@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
				write_script_isweka($scriptname . '_tt_' . $i . '.' . $sub_parm, 1);
				
				for $s_j(0..$#sub_grid_parms){
					@script_line = replace_grid_parm($grid_parms[$s_j][0],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 1],@script_line);
					write_script_prop($scriptname . '_tt_' . $i . '.' . $sub_parm, $grid_parms[$s_j][0] , $grid_parms[$s_j][$sub_grid_parms[$s_j] + 1]);
				}
				@script_line_out = ("java -Xmx$max_memory -cp weka.jar",$script_line[0],'-t train.arff -T test.arff -p 0',@script_line[1..$#script_line],'> out.txt');
				
				for $l(0..$outer_folds){
					if ($inner_folds){
						for $k(0..$inner_folds){
							$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_inner_' . $k . '_outer_' .$l;
							print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
							write_scripts_and_status($name,$out_filename,@script_line_out);
						}
					}
					$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_outer_' . $l;
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
					write_scripts_and_status($name,$out_filename,@script_line_out);
				}
				
				#Generate tasks for independent test 
				if ($main::independent_data){
					$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_independent';
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
					write_scripts_and_status($name,$out_filename,@script_line_out);
				}
			}

		}
	}
	
}

#*******************************************************************
#
# Function Name: creat_job_tt( $scriptname , $experiment_name 
#		, $max_memory , [@tt_arg] , [@tt_arg_grid] 
#		, $inner_folds , $outer_folds , $third_arg_type )
#
# Description: This function is to analysis the input of users, generate related script and status files.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@tt_arg: Modeling (train test) methods.
#		@tt_arg_grid: The parameter optimization information.
#		$inner_folds: The number of inner folds
#		$outer_folds: The number of outer folds
#		$third_arg_type : the type of the 3rd method, such as '3rd' , 'waffles' , etc.
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_tt_3rd{
	my $arg_name = $_[0];
	my $i = $_[1], my $j, my $k, my $l;
	my @tt_arg = @{$_[2]};
	my @tt_arg_grid = @{$_[3]};
	my $scriptname = $_[4];
	my ($inner_folds, $outer_folds) = @_[5,6];	
	my $third_arg_type = $_[7];
	my @grid_position = grep{$tt_arg_grid[$_] =~ m/^$tt_arg[$i]/g}(0..$#tt_arg_grid);
	my (@each_grid , $out_filename , @grid_parms);;
	if (@grid_position){
		#Create a temporary folder
		dircopy("$main::prog_dir/config/tt/$arg_name","$main::prog_dir/config/grid/$arg_name");
		@each_grid = split_grid(' ',$tt_arg_grid[$grid_position[0]]);
		for (@each_grid){$_ =~ s/###//;}
		for ($j = 1;$j <= $#each_grid;$j += 5){
			#split the parameters, for example
			#-c 1:5 => -c 1 2 3 4 5
			@grid_parms = (@grid_parms , [@each_grid[$j..$j+3],alalysis_grid_parm_3rd($each_grid[$j+4])]);
			#replace_grid_parm_3rd('clu',$arg_name,$grid_parms[$#grid_parms][0..4]);
		}
		my $sub_parm = -1;			
		my $grid_parm_num = 1;
		my @grid_parm_sub_num, my @sub_grid_parms, my $s_j;		
		for $j(0..$#grid_parms){
			$grid_parm_num = $grid_parm_num * ($#{$grid_parms[$j]} - 3);
			@grid_parm_sub_num = (@grid_parm_sub_num , $#{$grid_parms[$j]} - 3);
		}
		for $j(0..$grid_parm_num-1){
			$sub_parm++;
			@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
			
			write_script_isweka($scriptname . '_tt_' . $i .  '.' . $sub_parm, 0);
			my %changed_files;
			map{
				$changed_files{${$grid_parms[$_]}[0]}=1;
			}0..$#sub_grid_parms;
			map{
				recover_file('tt',$arg_name,$_);
			}keys(%changed_files);
			for $s_j(0..$#sub_grid_parms){
				replace_grid_parm_3rd('grid',$arg_name,@{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
				write_script_prop($scriptname . '_tt_' . $i .  '.' . $sub_parm, @{$grid_parms[$s_j]}[0..3],$grid_parms[$s_j][$sub_grid_parms[$s_j] + 4]);
			}
			
			for $l(0..$outer_folds){
				if ($inner_folds){
				for $k(0..$inner_folds){	
					$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_inner_' . $k . '_outer_' .$l;
					modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');			
					compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
					copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
					write_status($out_filename,'1');
					unlink "$main::prog_dir/config/grid/$arg_name/prop";
					}
				}
				$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_outer_' .$l;
				modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');	
				compress_dir($arg_name,'grid') if !-e "$main::prog_dir/config/grid/$arg_name" . '.tgz';
				copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");
				write_status($out_filename,'1');
				unlink "$main::prog_dir/config/grid/$arg_name/prop";
			}
			
			#Generate tasks for independent test
			if ($main::independent_data){
				$out_filename = $scriptname . '_tt_' . $i . '.' . $sub_parm . '_independent';
				print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
				copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");
				write_status($out_filename,'1');
			}
			 
			detail_back("$main::prog_dir/config/tt/$arg_name","$main::prog_dir/config/grid/$arg_name",\@grid_parms);
			unlink("$main::prog_dir/config/grid/$arg_name" . '.tgz');
		}
		rmtree("$main::prog_dir/config/grid/$arg_name");
	}
	else{
		write_script_isweka($scriptname . '_tt_' . $i, 0);
		write_script_prop($scriptname . '_tt_' . $i, 'default');
		#Add some action for waffles
		my $arg_type = 'tt';
		if ($third_arg_type eq 'waffles'){
			dircopy("$main::prog_dir/config/tt/$arg_name","$main::prog_dir/config/grid/$arg_name");
			$arg_type = 'grid';
		}
		for $l(0..$outer_folds){
			if ($inner_folds){
				for $k(0..$inner_folds){	
					$out_filename = $scriptname . '_tt_' . $i . '_inner_' . $k . '_outer_' .$l;
					modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';
					print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');				
					compress_dir($arg_name,$arg_type) if !-e "$main::prog_dir/config/$arg_type/$arg_name" . '.tgz';
					copy("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
					write_status($out_filename,'1');
					unlink "$main::prog_dir/config/$arg_type/$arg_name/prop";
				}
			}
			$out_filename = $scriptname . '_tt_' . $i . '_outer_' .$l;
			modify_waffles_out_num('grid',$arg_name) if $third_arg_type eq 'waffles';
			print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
			compress_dir($arg_name,$arg_type) if !-e "$main::prog_dir/config/tt/$arg_name" . '.tgz';
			copy("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");				
			write_status($out_filename,'1');
			unlink "$main::prog_dir/config/$arg_type/$arg_name/prop";
		}
		
		#Generate tasks for independent test
		if ($main::independent_data){
			$out_filename = $scriptname . '_tt_' . $i . '_independent';
			print_step_prop("$main::prog_dir/results/$main::name/stepprops/$out_filename",'tt');
			copy("$main::prog_dir/config/grid/$arg_name" . '.tgz' , "$main::prog_dir/results/$main::name/scripts/$out_filename");
			write_status($out_filename,'1');
		}
							
		rmtree("$main::prog_dir/config/grid/$arg_name") if $third_arg_type eq 'waffles';
		unlink("$main::prog_dir/config/$arg_type/$arg_name" . '.tgz');
	}
	
	unlink("$main::prog_dir/config/tt/$arg_name" . '.tgz');
}

#*******************************************************************
#
# Function Name: creat_job_for_all( $scriptname , $method_type )
#
# Description: 
#		Create a ¡°completed¡± task for the special situation that users add the 
#		value ¡®all¡¯ in the out number of dimension reduction. In this case, 
#		the related task would be considered as complete because there is 
#		no necessary for dimension reduction.
#
# Parameters:
#
# 		$script_name: The name of the script
#		$experiment_name: The name of the experiment
#		$max_memory: The allowed use of memory. (Only valid for weka tasks)
#		@tt_arg: Modeling (train test) methods.
#		@tt_arg_grid: The parameter optimization information.
#		$inner_folds: The number of inner folds
#		$outer_folds: The number of outer folds
#		$third_arg_type : the type of the 3rd method, such as '3rd' , 'waffles' , etc.
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_job_for_all{
	my ($scriptname , $type) = @_;
	my $out_filename = $scriptname . '_' . $type . '_' . '-1' . '_' . 'all';
	return if -f "$main::prog_dir/results/$main::name/status/$out_filename";
	copy("$main::prog_dir/results/$main::name/data/$scriptname" . '.arff' , "$main::prog_dir/results/$main::name/data/$out_filename" . '.arff');
	write_status($out_filename,'3');
}

#*******************************************************************
#
# Function Name: alalysis_grid_parm( $string )
#
# Description: 
#		Analysis the input of parameter optimization, 
#		generate the details and return them.
#		For example, if the $string is ¡°4:6¡±, 
#		then the return ARRAY would be (4 , 5 , 6).
#
# Parameters:
#
# 		$string: The string record the ranged values of a parameter
#
# Return:
#
#		An ARRAY of the details of the changed parameters.
#
#*********************************************************************

sub alalysis_grid_parm{
	#Analyze the input of parameter optimization; generate the details and return them. 
	#
	#For example, if the $string is ¡°4:6¡±, the return ARRAY would be (4 , 5 , 6).

	my $grid_line = $_[0];
	my @sub_grid_lines;
	my @out_old;
	my @outputs;
	if ($grid_line =~ /\*\*\*\*/){
		@sub_grid_lines = split /\*\*\*\*/,$grid_line;
	}
	else{
		@sub_grid_lines = ($grid_line);
	}
	for my $sub_grid_line(@sub_grid_lines){
		my @out;
		$sub_grid_line = '' if !$sub_grid_line;
		$sub_grid_line =~ s/~~~;/~~~~/;
		my @each_sub_grid = split(m/;/,$sub_grid_line);
		map{$_ =~ s/~~~~/;/}@each_sub_grid;
		foreach $sub_grid_line(@each_sub_grid){
			#a:b
			if ($sub_grid_line =~ m/^([-\d\.]+):([-\d\.]+)$/){@out = (@out,($1..$2));}
			#a:b:c
			elsif ($sub_grid_line =~ m/^([-\d\.]+):([-\d\.]+):([-\d\.]+)$/){@out = (@out,map{$1 + $2 * $_}(0..my_int(($3 - $1) / $2)));}
			#a^b:c
			elsif($sub_grid_line =~ m/^([-\d\.]+)\^([-\d\.]+):([-\d\.]+)$/){@out = (@out,map{$1 ** ($2 + $_)}(0..my_int($3 - $2)));}
			#a^b:c:d
			elsif ($sub_grid_line =~ m/^([-\d\.]+)\^([-\d\.]+):([-\d\.]+):([-\d\.]+)$/){@out = (@out,map{$1 ** ($2 + $3 * $_)}(0..my_int(($4 - $2) / $3)));}
			#a^b
			elsif ($sub_grid_line =~ m/^([-\d\.]+)\^([-\d\.]+)$/){@out = (@out,$1 ** $2);}
			else {@out = (@out,$sub_grid_line);}
		}
		map{$_ =~ s/~~~//}@out;
		push @outputs,[@out];
	}
	#link the parts in outputs
	my @out;
	if ($#outputs == 0){
		@out = @{$outputs[0]};
	}else{
		@out_old = @{$outputs[0]}; 
		for my $i(1..$#outputs){
			for my $each_out(@out_old){
				map{
					push @out,$each_out . $_;
				}@{$outputs[$i]}
			}
			@out_old = @out;
			@out = ();
		}
		@out = @out_old;
	}

	
	
	return @out;
	
}

#*******************************************************************
#
# Function Name: my_int( $in )
#
# Description: 
#		A fix for the function int of Perl, in case of the situation 
#		that the int 2.9999999999999... would be returned 2, 
#		but the 3 is acutraly needed 
#
# Parameters:
#
# 		$in: The input number
#
# Return:
#
#		A value of the nearest interger of the $in.
#
#*********************************************************************

sub my_int{
	#A fix for the function int of Perl,some times the int 2.9999999999999... would be returned 2 
	#but the 3 is acutraly needed 
	my $in = $_[0];
	my $threshold = 10**-7;
	return int($in) + 1 if abs($in - int($in) - 1) < $threshold;
	return int($in); 
}

#*******************************************************************
#
# Function Name: alalysis_grid_parm_3rd( $string )
#
# Description: 
#		Analyze the input of parameter optimization for 3rd program;
#		Generate the details and return them.
#
# Parameters:
#
# 		$string: The string record the ranged values of a parameter
#
# Return:
#
#		An ARRAY of the details of the changed parameters.
#
#*********************************************************************

sub alalysis_grid_parm_3rd{
	#Analyze the input of parameter optimization for 3rd program;
	#Generate the details and return them.
	my $sub_grid_line = $_[0];
	$sub_grid_line = '' if !$sub_grid_line;
	my @out;
	if ($sub_grid_line =~ /&&&/){
		my @sub_grids = split /&&&/,$sub_grid_line;
		my (@each_sub_grid , $i , $j , $k , @grid_parm_sub_num , @sub_grid_parms);
		for $i(@sub_grids){
			push @each_sub_grid,[alalysis_grid_parm($i)];
		}
		my $grid_parm_num = 1;
		for $j(0..$#each_sub_grid){
			$grid_parm_num = $grid_parm_num * ($#{$each_sub_grid[$j]} + 1);
			push(@grid_parm_sub_num , $#{$each_sub_grid[$j]} + 1);
		}
		for $j(0..$grid_parm_num-1){
			#@sub_grid_parms here is used for record the position
			@sub_grid_parms = get_grid_position($j , @grid_parm_sub_num);
			push @out,join('&&&',map{$each_sub_grid[$_][$sub_grid_parms[$_]]}(0..$#sub_grid_parms));
		}
	}
	else{
		@out = alalysis_grid_parm($sub_grid_line);
	}
	return @out;
}

#*******************************************************************
#
# Function Name: replace_grid_parm( $para_name , $para_value , @script_line )
#
# Description: 
#		Replace the value of specified parameter in the related line.
#
# Parameters:
#
# 		$para_name: The name of the parameter which need to be replace
#		$para_value: The value of the parameter which need to be replace
#		@script_line: The separated line which contains the parameter.
#
# Return:
#
#		The changed @script_line
#
#*********************************************************************

sub replace_grid_parm{
	#Replace the value of specified parameter in the related line.
	(my $para_name , my $para_value , my @script_line ) = @_;
	my @para_position = grep{if ($script_line[$_] =~ m/$para_name/g){$_;}}(1..$#script_line)  ;
	if (@para_position){
		if ($para_value eq '_OFF_'){
			if (!$script_line[$para_position[0]+1] || $script_line[$para_position[0]+1] =~ m/^-[^\d]/){
				#Only delete the parameter if no value of it
				splice @script_line,$para_position[0],1;
			} 
			else{
				#Delete the parameter and its value
				splice @script_line,$para_position[0],2;
			}
		}
		elsif ($para_value eq '_ON_'){}
		else{
			$script_line[$para_position[0]+1] =~ s/[-\w\.]+/$para_value/g;  
		}
	}
	else {
		#Add the elemets start from the second position 
		if ($para_value eq '_ON_'){@script_line = ($script_line[0],$para_name,@script_line[1..$#script_line]);}
		else {@script_line = ($script_line[0],$para_name,$para_value,@script_line[1..$#script_line]);}
	}
	return @script_line;
}

#*******************************************************************
#
# Function Name: write_scripts_and_status( $experiment_name , $out_name , @script_details )
#
# Description: 
#		Generate the script file and status file for task executing.
#
# Parameters:
#
# 		$experiment_name: The name of the experiment
#		$out_name: The name of the script/status file
#		@script_details: The details in the output file.
#
# Return:
#
#		None
#
#*********************************************************************

sub write_scripts_and_status{
	#Generate the script file and status file for task executing.
	(my $name,my $out_filename,my @script_line) = @_;
	open(FID_scr,">$main::prog_dir/results/$name/scripts/$out_filename");
	print FID_scr join(' ',@script_line),"\n";
	close FID_scr;
	open(FID_sta,">$main::prog_dir/results/$name/status/$out_filename");
	print FID_sta "1\n";
	close FID_sta;
}

#*******************************************************************
#
# Function Name: write_status( $out_name , $statue_value )
#
# Description: 
#		Generate the status file for task executing.
#
# Parameters:
#
#		$out_name: The name of the script/statue file
#		$statue_value: The value of the status file.
#
# Return:
#
#		None
#
#*********************************************************************

sub write_status{
	#Only generate the status file.
	my ($out_filename , $statue_value) = @_;
	open(FID_sta,">$main::prog_dir/results/$main::name/status/$out_filename");
	print FID_sta "$statue_value\n";
	close FID_sta;
}

#*******************************************************************
#
# Function Name: get_grid_position( $num , @seq )
#
# Description: 
#		Get the number of tasks in the changed parameters of one method.
#		For example, if a method has 3 parameters, A, B and C which need 
#		to be changed, and the details are ¡®-A 1:3 -B 1:5 -C YES;NO¡¯,
#		then there would be 30 scripts need to be generated. 
#
#		This function maps each combination of changed parameters to the
#		sequence number 1-30. There the value 1 mapped with ¡®-A 1 -B 1 -C YSE¡¯,
#		 10 with ¡®-A 1 -B 4 -C YES¡¯.
#
# Parameters:
#
#		$num: The number of the changed method
#		@seq: The number of ranged values of each parameters, for example,
#			  the @seq is ( 3 , 5 , 2 ) from the string ¡®-A 1:3 -B 1:5 -C YES;NO¡¯
#
# Return:
#
#		An ARRAY of the position of each changed parameters.
#		The length is the number of changed parameters of this method.
#
#*********************************************************************

sub get_grid_position{
	(my $num, my @seq) = @_;
	my @position = @seq;#carry the number of the elemets in @seq form left to right 
	@position = map{$_ = 0}@position;
	my $root = 0;
	while ( int($num / $seq[$root]) > 0){
		
		$position[$root] = $num % $seq[$root];
		$num = int($num / $seq[$root]);
		if ($root == $#seq){die 'too many grid parms';}
		$root++;
	}
	$position[$root] = $num % $seq[$root];
	return @position;
}

#*******************************************************************
#
# Function Name: creat_floders()
#
# Description: Create required folders for new experiment.
#
# Parameters:
#
#		None
#
# Return:
#
#		None
#
#*********************************************************************

sub creat_floders{
#	Create required folders for new experiment.
#	Usage:
#	creat_folders();
	
	my $dir_name = "$main::prog_dir/results/$main::name";
	mkdir 'sample_results' if !-d 'sample_results';
	mkdir "$main::prog_dir/results" if !-d "$main::prog_dir/results";
	mkdir "$main::prog_dir/results/$main::name" if !-d "$main::prog_dir/results/$main::name";
	
	mkdir "$main::prog_dir/results/$main::name/data" if !-d "$main::prog_dir/results/$main::name/data";
	mkdir "$main::prog_dir/results/$main::name/orgdata" if !-d "$main::prog_dir/results/$main::name/orgdata";
	
	mkdir "$main::prog_dir/results/$main::name/err" if !-d "$main::prog_dir/results/$main::name/err";
	mkdir "$main::prog_dir/results/$main::name/err/results" if !-d "$main::prog_dir/results/$main::name/err/results";
	mkdir "$main::prog_dir/results/$main::name/err/scripts" if !-d "$main::prog_dir/results/$main::name/err/scripts";
	
	mkdir "$main::prog_dir/results/$main::name/complete" if !-d "$main::prog_dir/results/$main::name/complete";
	mkdir "$main::prog_dir/results/$main::name/complete/results" if !-d "$main::prog_dir/results/$main::name/complete/results";
	mkdir "$main::prog_dir/results/$main::name/complete/scripts" if !-d "$main::prog_dir/results/$main::name/complete/scripts";
	
	mkdir "$main::prog_dir/results/$main::name/scripts" if !-d "$main::prog_dir/results/$main::name/scripts";
	mkdir "$main::prog_dir/results/$main::name/status" if !-d "$main::prog_dir/results/$main::name/status";
	mkdir "$main::prog_dir/results/$main::name/results" if !-d "$main::prog_dir/results/$main::name/results";
	mkdir "$main::prog_dir/results/$main::name/jobprops" if !-d "$main::prog_dir/results/$main::name/jobprops";
	mkdir "$main::prog_dir/results/$main::name/stepprops" if !-d "$main::prog_dir/results/$main::name/stepprops";
}

#*******************************************************************
#
# Function Name: compress_dir( $method_name , $method_type )
#
# Description: 
#		Compress the specified method for the next step.
#		Use .tgz format because some bugs of .zip when testing on windows 
#
# Parameters:
#
#		$method_name: The name of the output file
#		$method_type: The type of the used method (clu/fea/tt/grid).
#					  This parameter is used to decide the subfolder 
#					  for the .tgz file 
#
# Return:
#
#		None
#
#*********************************************************************

sub compress_dir{
	my $tar = Archive::Tar->new;
	my $arg_name = $_[0];
	my $arg_type = $_[1];
	my $pwd = getcwd();
	chdir "pml/config/$arg_type/$arg_name";
	my @list, my @list_out;
	@list = <*>;
	while ($#list > -1){
		if (-d $list[0]){
			push(@list , <$list[0]/*>);
			shift(@list);
		}
		else {
			push(@list_out,$list[0]);
			shift(@list);
		}
	}
	$tar->add_files(@list_out);
	$tar->write("../$arg_name" . '.tgz' , $main::compress_level  );
	chdir $pwd;
}

#*******************************************************************
#
# Function Name: get_split_grid( $p , $line )
#
# Description: 
#		Separate the line into elements by methods for the next operations.
#
# Parameters:
#
#		$p: The pattern to separate the line.
#		$line: The line of the optimization information written by users.
#
# Return:
#
#		An ARRAY with separated information of methods.
#
#*********************************************************************

sub get_split_grid{
	#Separate the line into elements by methods for the next operations.
	my ($p , $grid_line ) = @_;
	my @list = split /###/s,$grid_line;
	my @l;
	my @list_out;
	my $i = 0;	
	if ($#list == 0){
		@list_out = split(/$p/s,$grid_line);		
	}
	else{
		for ($i = 0 ; $i + 1 <= $#list ;$i += 6){
			@l = split(/$p/s,$list[$i]);
			@l = grep{$_}@l;
			$l[$#l] .= '###' . join('###',@list[$i+1..$i+5]) .'###';
			push(@list_out,@l) if @l;
		}
		if ($#list % 2 == 0){
			@l = split(/$p/s,$list[$#list]);
			@l = grep{$_}@l;
			push(@list_out,@l);
		}
	}
	return @list_out;
}

#*******************************************************************
#
# Function Name: split_grid( $p , $line )
#
# Description: 
#		Separate the line into elements by methods for the next operations.
#
# Parameters:
#
#		$p: The pattern to separate the line.
#		$line: The line of the optimization information written by users.
#
# Return:
#
#		An ARRAY with separated information of methods.
#
#*********************************************************************

sub split_grid{
	#Separate the line into elements by the ¡¯###¡¯ partten.

	my ($p , $grid_line ) = @_;
	my @list = split /###/s,$grid_line;
	my @l;
	my @list_out;
	my $i = 0;	
	if ($#list == 0){
		@list_out = split(/$p/s,$grid_line);		
	}
	else{
		for ($i = 0 ; $i + 1 <= $#list ;$i += 2){
			@l = split(/$p/s,$list[$i]);
			@l = grep{$_}@l;
			push(@list_out,@l) if @l;
			push(@list_out,$list[$i+1]);
		}
		if ($#list % 2 == 0){
			@l = split(/$p/s,$list[$#list]);
			@l = grep{$_}@l;
			push(@list_out,@l);
		}
	}
	return @list_out;
}

#*******************************************************************
#
# Function Name: recover_file ($method_type , $method_name , $file_name)
#
# Description: 
#		This function action similar with function detail_back. The difference
#		 is that this function could figure out and recover the files with
#		the same names in the platform subfolders.
#
# Parameters:
#
#		$method_type: clu, fea or tt
#		$method_name: the name of the method
#		$file_name: the name of the file which need to be recover
#
# Return:
#
#		None
#
#*********************************************************************

sub recover_file{
	#This function acts similar with function detail_back. 
	#The difference is that this function could figure out and recover the files with same names in the platform subfolders.
	my ($arg_type,$arg_name,$file_name_all)=@_;
	my @subfiles = ('','linux/','win/','linux_x86/','linux_x86_64/','win_x86/','win_x86_64/');
	for my $file_name (@subfiles){
		next if !-f "$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all;
		copy "$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all,"$main::prog_dir/config/grid/$arg_name/$file_name" . $file_name_all
	}
}

#*******************************************************************
#
# Function Name: modify_waffles_out_num ($method_type , $method_name , $out_num)
#
# Description: 
#		Modify the cluster/varselect output infomation for the script 
#		in order to get the correct output dimension.
#
# Parameters:
#
#		$method_type: clu, fea, tt or grid (correspond with the subfolder)
#		$method_name: the name of the method
#		$out_num: the dimension of the output dataset
#
# Return:
#
#		None
#
#*********************************************************************

sub modify_waffles_out_num{
	#Modify the cluster/varselect output infomation to the script
	my ($arg_type , $arg_name , $out_num) = @_;
	our (%waffles_arg , %waffles_clu , %waffles_fea);
	my @subfiles = ('','linux/','win/','linux_x86/','linux_x86_64/','win_x86/','win_x86_64/');
	my $file_name_all = 'script';
		for my $file_name (@subfiles){
			next if !-f "$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all;
			open(FID,"$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all);
			my $line;
			my @lines = <FID>;
			close FID;
			for $line(@lines){
				#get the cmd contain waffles_*** ...
				if ($line =~ /^waffles_/ || $line =~ /^\.\/waffles_/){
					$line =~ s/\s+$//;
					my @elements = split /\s+/,$line;
					$elements[0] =~ s/\.exe$//;
					
					my $position = 0;
					for (@elements){
						last if $_ eq '-seed';
						$position++;
					}
					
					if ($elements[1] ne 'attributeselector'){
						my $waf_name = $elements[0];
						$waf_name =~ s/^\.\///;
						my %hash_arg;
						my %hash_option;
						%hash_arg = %{$waffles_arg{$waf_name}} if $waffles_arg{$waf_name};
						%hash_option = %{$hash_arg{$elements[1]}} if $hash_arg{$elements[1]};
						my $position = 0;
						#Find the stdout simbol '>'
						for (@elements){
							last if $_ eq '>';
							$position++;
						}
						my $position_out = $position;
						
						$position = 0;
						#Find the parameter '-seed;
						for (@elements){
							last if $_ eq '-seed';
							$position++;
						}
						
						#get the seed
						my $seed;
						if ($elements[0] =~ /cluster/){
							$seed = $main::seed_clu;
						}
						elsif ($elements[0] =~ /dimred/){
							$seed = $main::seed_fea;
						}
						else{
							$seed = $main::globle_seed;
						}
						
						if ($position > $position_out){
							#Insert the '-seed' parameter
							splice @elements,$position_out,0,('-seed',$seed);
						}
						else{
							$elements[$position + 1] = $seed;
						}
						
						
						if ($out_num){
							#Change the dimention number
							$position = -1;
							for (@elements){
								last if exists $hash_option{$_};
								$position++;
							}
							$elements[$position] = $out_num;
						}
						$line = join ' ',@elements;
						$line .= "\n";
					}
					else{
						my $position = 0;
						#Find the parameter '-seed;
						for (@elements){
							last if $_ eq '-seed';
							$position++;
						}
						
						if ($position > $#elements){
							$position = $#elements; 
							$elements[$position + 1] = '-seed';
							$elements[$position + 2] = $main::seed_fea;
						}
						else{
							$elements[$position + 1] = $main::seed_fea;
						}
						
						#Change the out dimention number
						$position = -1;
						for (@elements){
							last if $_ eq '-out';
							$position++;
						}
						#if parameter '-out' missed, it will be added after the last parameter
						$position = $#elements if $position > $#elements;
						$elements[$position + 1] = '-out';
						$elements[$position + 2] = $out_num;
						$elements[$position + 3] = 'out.txt';
						$line = join ' ',@elements;
						$line .= "\n";
					}
				}
			}
			open(FID_O,">$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all);
			print FID_O @lines;
			close FID_O;
		}
}

#*******************************************************************
#
# Function Name: replace_grid_parm_3rd($method_type, $method_name,
#					 $file_name, $org_str, $p, $num, $change)
#
# Description: 
#		Replace the value of specified parameter by modifying the related file.
#		Note that '_ON_' is not supported
#		Example:
#		(a,b)=function(c,d,e)
#		file ###c,d,e### ###,### 1 ###1:3###
#		then c would change 1 to 1 2 or 3
#
# Parameters:
#
# 		$method_type: clu, fea or tt
#		$method_name: The name of the 3rd method
#		$file_name: The name of the file which contain the needed parameter.
#		$org_str: The string used to be matched in the file
#		$p: The pattern to separate the line.
#		$num: To specify the separated elements.
#		$change: Change the specified element.
#
# Return:
#
#		None
#
#*********************************************************************
 
sub replace_grid_parm_3rd{
	#Replace the value of specified parameter by modifying the related file.
	#_ON_ is not supported
	#     Example:
	#     (a,b)=function(c,d,e)
	#     file ###c,d,e### ###,### 1 ###1:3###
	#then c would change 1 to 1 2 or 3
	my ($arg_type,$arg_name,$file_name_all,$org_str,$p,$num_all,$change) = @_;
	my $org_out;
	#Consider the subfolders for platforms.
	my @subfiles = ('','linux/','win/','linux_x86/','linux_x86_64/','win_x86/','win_x86_64/');
	for my $file_name (@subfiles){	
		my $num = $num_all;
		next if !-f "$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all;
		open(FID,"$main::prog_dir/config/$arg_type/$arg_name/$file_name" . $file_name_all);
		my $line;
		my @lines = <FID>;
		close FID;
		my (@grid_parms , @nums , @changes , $i);
		if ($num =~ /;/){
			@nums = split /;/,$num;
			@nums = map{$_ - 1}@nums;
			@changes = split /&&&/,$change;
		}
		else{
			$num -= 1;
		}
		
		for $line(@lines){
			if ($line =~ m!$org_str!s){
				@grid_parms = split /$p/s,$org_str;
				if (@nums){
					for $i(0..$#nums){
						if ($changes[$i] eq '_OFF_'){
							#delete @grid_parms[$nums[$i]];
							@grid_parms[$nums[$i]] = 'delete_this_parameter';
						}
						else{
							$grid_parms[$nums[$i]] = $changes[$i];
						}
					}
					#@grid_parms = grep{$_}@grid_parms;				
					@grid_parms = grep{$_ ne 'delete_this_parameter'}@grid_parms;
				}
				else{
					if ($change eq '_OFF_'){
						splice(@grid_parms,$num,1);
					}
					else{
						$grid_parms[$num] = $change;
					}				
				}
				$org_out = join("$p",@grid_parms);
				$line =~ s!$org_str!$org_out!s;
			}
		}
		open(FID_OUT,">$main::prog_dir/config/grid/$arg_name/$file_name" . $file_name_all);
		print FID_OUT @lines;
		close FID_OUT;
	}
}

#*******************************************************************
#
# Function Name: data_copy( $file_in , $file_out )
#
# Description: 
#		Copy the ARFF data file and escape the lines only with /\s+/
#		Change the sparse data into dense
#		This function is only used for reducing the error when modifying the ARFF file.
#
# Parameters:
#
# 		$file_in: The path of source file.
#		$file_out: The target path.
#
# Return:
#
#		None
#
#*********************************************************************
 
sub data_copy{
	my ($file_in,$file_out) = @_;
	open(FID,$file_in);
	open(FID_O,">$file_out");
	my $line;
	my @labels;
	my $switch;
	my $att_count = 0;
	while ($line = <FID>){
		#$line =~ s/\'//g;
		next if $line =~ /^\s*\n$/;
		if($line =~ /^\@attribute/i){
			print FID_O $line;
			$att_count++;
		}
		elsif($line =~ /^\@data/i){
			print FID_O $line;
			$switch++;
		}
		elsif($switch){
			if($line =~ /^\{([^\}]+)\}/){				
				my @eles = split /,/,$1;
				my %hash_ele;
				map{
					if($_ =~ /(\d+)\s+(\S+)/){
						$hash_ele{$1} = $2;
					}
				}@eles;
				my @atts;
				map{
					$atts[$_] = 0;
					$atts[$_] = $hash_ele{$_} if exists $hash_ele{$_};
				}0..$att_count - 1;
				print FID_O join ',',@atts;
				print FID_O "\n";
			}
			else{
				print FID_O $line;
			}
		}
		else{
			print FID_O $line;
		}
		#print FID_O $line;
	}
	close FID;
	close FID_O;
}

#*******************************************************************
#
# Function Name: write_script_isweka( $file_name , $isweka )
#
# Description: 
#		Write the information into specified file for result analysis.
#
# Parameters:
#
# 		$file_name: The name of the out file.
#		$isweka: 0 or 1.
#
# Return:
#
#		None
#
#*********************************************************************

sub write_script_isweka{
	#Write the information into specified file for result analysis.
	my ($prop_name,$isweka) = @_;
	open (FID,">$main::prog_dir/results/$main::name/jobprops/$prop_name");
	if ($isweka){
		print FID "Job proportion : weka\n";
	}else{
		print FID "Job proportion : 3rd part software\n";
	}
	print FID "Parameters:\n";
	close FID;
}

#*******************************************************************
#
# Function Name: write_script_prop( $file_name , @details )
#
# Description: 
#		Write the information into specified file for result analysis.
#
# Parameters:
#
# 		$file_name: The name of the out file.
#		@details: The details in the file
#
# Return:
#
#		None
#
#*********************************************************************

sub write_script_prop{
	#Write the information into specified file for result analysis.
	my ($prop_name,@lines) = @_;
	open (FID,">>$main::prog_dir/results/$main::name/jobprops/$prop_name");
	print FID join ' ',@lines;
	print FID "\n";
	close FID;
}

#*******************************************************************
#
# Function Name: detail_back( $org_path , $target_path , \@grid_parms )
#
# Description: 
#		Write the information into specified file for result analysis.
#
# Parameters:
#
# 		$org_path: The path of the original folder.
# 		$target_path: The path of the target folder.
#		\@grid_parms: The changed file names
#
# Return:
#
#		None
#
#*********************************************************************

sub detail_back{
	#Copy specified files.
	#During the process of parameter optimization for 3rd program, some files might be changed, 
	#thus these files need to be recovered, which is realized by this function.

	my ($org_path , $target_path , $grid_parms_l) = @_;
	for my $i (0..$#$grid_parms_l){
		copy("$org_path/$$grid_parms_l[$i][0]" , "$target_path/$$grid_parms_l[$i][0]");
	}
}

#*******************************************************************
#
# Function Name: print_step_prop( $file_name , @details )
#
# Description: 
#		Generate a file to help PML executing tasks in parallel.
#
# Parameters:
#
# 		$file_name: The name of the out file.
#		@details: The details in the file
#
# Return:
#
#		None
#
#*********************************************************************

sub print_step_prop{
	#Generate a file to help PML to execute tasks in parallel.
	my ($file_name , @detail) = @_;
	open(FID,">$file_name");
	print FID join(' ' , @detail);
	close FID;
}

#*******************************************************************
#
# Function Name: get_threads_number()
#
# Description: 
#		Get the number of threads of one machine. Note that the  
#		number of threads might be multiple of CPU cores due to the 
#		Intel hyper-threading technology. 
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

sub get_threads_number{
	#Get the number of threads of one machine.
	#Note that the number of threads might be multiple of CPU cores in terms of Intel hyper-threading technology. 

	my $core_num;
	if ($^O =~ /win/i){
		$core_num = $ENV{'NUMBER_OF_PROCESSORS'};
	}
	else{
		#linux
		$core_num = `cat /proc/cpuinfo | grep "physical id" | sort | wc -l`;
		$core_num =~ s/\s//;
	}
	return $core_num;
}

#*******************************************************************
#
# Function Name: init_wu()
#
# Description: 
#		Create the folders for parallel computing of PML-desktop. 
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

sub init_wu{
	#Create the folders for parallel computing of PML-desktop.
	mkdir "$main::prog_dir/wus" if !-d "$main::prog_dir/wus";
	for my $i(1..$main::core_number){
		mkdir "$main::prog_dir/wus/wu$i" if !-d "$main::prog_dir/wus/wu$i";
#		open FID,">$main::prog_dir/wus/wu" . $i . '.statue';
#		print FID '0';
#		close FID;
		copy "$main::prog_dir/src/job_execute_desktop.pl","$main::prog_dir/wus/run" . $i . ".pl";
	}
}

#*******************************************************************
#
# Function Name: dircopy($dir_source , $dir_target);
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

#*******************************************************************
#
# Function Name: rmtree( $folder_path )
#
# Description: 
#		Delete specified folder.
#
# Parameters:
#
# 		$folder_path: The path of the folder which expected to be deleted.
#
# Return:
#
#		None
#
#*********************************************************************

sub rmtree{
	#Delete specified folder.
	my $rmdir_root = $_[0];
	my @files = <$rmdir_root/*>;
	while ($#files > -1){
		my $file = $files[$#files];
		if (-f $file){
			unlink $file;
			pop @files;
		}
		elsif(-d $file){
			my @subfiles = <$file/*>; 
			if ($#subfiles > -1){
				push @files,@subfiles;
			}
			else{
				rmdir $file;
				pop @files;
			}
		}
	}
	rmdir $rmdir_root;
}

#*******************************************************************
#
# Function Name: get_job_num(\%hash_tasks)
#
# Description: 
#		Analysis the input of users and estimate the number of tasks.
#		The hash table %hash_tasks would be recorded with the details of tasks
#		 after finish this function and could be used for function del_job_num()
#
# Parameters:
#
# 		%hash_tasks: The records of the details of tasks. (This hash 
#			table is empty at first)
#
# Return:
#
#		The number of tasks.
#
#*********************************************************************

sub get_job_num{
	#Analyze the input of users and estimate the number of tasks.
	my ($hash_tasks_l) = @_;
	my $job_num = 1;
	if (@main::cluster_arg){
		for (@main::cluster_arg){
			my $arg_num = $_;
			my $grid_num = get_grid_num($arg_num,'cluster'); 
			$$hash_tasks_l{'clu'.$arg_num.'_para_num'} = $grid_num;
			$$hash_tasks_l{'clu_para_num'} += $grid_num;
		}
		$$hash_tasks_l{'clu_arg_num'} = scalar @main::cluster_arg;
		$$hash_tasks_l{'clu_out_num'} = scalar @main::cluster_out_instances;
		$$hash_tasks_l{'clu_out_all'} = 0;
		if(grep{$_ eq 'all'}@main::cluster_out_instances){
			$$hash_tasks_l{'clu_out_num'}--;
			$$hash_tasks_l{'clu_out_all'}++;
		}
		
	}
	if (@main::feature_select_arg){
		for (@main::feature_select_arg){
			my $arg_num = $_;
			my $grid_num = get_grid_num($arg_num,'feature'); 
			$$hash_tasks_l{'fea'.$arg_num.'_para_num'} = $grid_num;
			$$hash_tasks_l{'fea_para_num'} += $grid_num;
		}
		$$hash_tasks_l{'fea_arg_num'} = scalar @main::feature_select_arg;
		$$hash_tasks_l{'fea_out_num'} = scalar @main::feature_out_features;
		$$hash_tasks_l{'fea_out_all'} = 0;
		if(grep{$_ eq 'all'}@main::feature_out_features){
			$$hash_tasks_l{'fea_out_num'}--;
			$$hash_tasks_l{'fea_out_all'}++;
		}
		
	}
	if (@main::tt_arg){
		for (@main::tt_arg){
			my $arg_num = $_;
			my $grid_num = get_grid_num($arg_num,'traintest'); 
			$$hash_tasks_l{'tt'.$arg_num.'_para_num'} = $grid_num;
			$$hash_tasks_l{'tt_para_num'} += $grid_num;
		}
		$$hash_tasks_l{'tt_arg_num'} = scalar @main::tt_arg;
		$$hash_tasks_l{'tt_in_num'} = $main::inner_folds;
		$$hash_tasks_l{'tt_out_num'} = $main::outer_folds;
	}
	
	my @step = @main::step;
	my $independent_count = 0;
	$independent_count++ if $main::independent_data;
	while(@step){
		my $last_step = pop @step;
		if ($last_step eq 'clu'){
			$job_num *= $$hash_tasks_l{'clu_para_num'} * $$hash_tasks_l{'clu_out_num'} + $$hash_tasks_l{'clu_out_all'};
		}
		elsif($last_step eq 'fea'){
			$job_num *= $$hash_tasks_l{'fea_para_num'} * $$hash_tasks_l{'fea_out_num'} + $$hash_tasks_l{'fea_out_all'};
		}
		elsif($last_step eq 'tt'){
			$job_num *= $$hash_tasks_l{'tt_para_num'} * ($$hash_tasks_l{'tt_out_num'} * ($$hash_tasks_l{'tt_in_num'} + 1) + $independent_count);
		}
		$job_num++ if @step;
	}
	
	
	return $job_num;
}

#*******************************************************************
#
# Function Name: del_job_num ( $job_name , $hash_tasks_l )
#
# Description: 
#		PML could estimate the number of tasks which need to be executed.
#		However, if a task failed, which means the related tasks would be canceled, 
#		this function could calculate the number of canceled tasks.
#
# Parameters:
#
# 		$job_name: The name of the task with error
#		$hash_tasks_l: A reference of the hash table %hash_tasks which generated by get_job_num()
#
# Return:
#
#		The number of canceled tasks.
#
#*********************************************************************

sub del_job_num{
	my ($job_name , $hash_tasks_l)=@_;
	my $last_step = pop @{[grep{$_ =~ /^[cft]/}split /_/,$job_name]};
	my $step_position = pop @{[grep{$last_step eq $main::step[$_]}0..$#main::step]};
	my @next_steps = @main::step[$step_position + 1 .. $#main::step];
	my $del_num = 1;
	
	while(@next_steps){
		my $step = pop @next_steps;
		if ($step eq 'clu'){
			$del_num *= $$hash_tasks_l{'clu_para_num'} * $$hash_tasks_l{'clu_out_num'} + $$hash_tasks_l{'clu_out_all'};
		}
		elsif($step eq 'fea'){
			$del_num *= $$hash_tasks_l{'fea_para_num'} * $$hash_tasks_l{'fea_out_num'} + $$hash_tasks_l{'fea_out_all'};
		}
		elsif($step eq 'tt'){
			$del_num *= $$hash_tasks_l{'tt_para_num'} * $$hash_tasks_l{'tt_out_num'} * ($$hash_tasks_l{'tt_in_num'} + 1);
		}
		$del_num++ if @next_steps;
	}
	$del_num++ if $del_num != 1;
	return $del_num;
}

#*******************************************************************
#
# Function Name: get_grid_num($method_num, $method_type)
#
# Description: 
#		Estimate the total number of changed values of specified method.
#
# Parameters:
#
# 		$method_num: The number of utilized method
#		$method_type: clu, fea or tt
#
# Return:
#
#		The number of changed values
#
#*********************************************************************

sub get_grid_num{
	#Estimate the total number of changed values of specified method.
	my ($arg_num,$arg_type) = @_;
	my $isweka = 0;
	open(FID_ARG,"$main::prog_dir/config/$arg_type");
	while ( my $line = <FID_ARG>){
		if ($^O !~ m/win/){$line =~ s/\r\n$/\n/;}
		if ($line =~ m/^(\d+)\.(\w+)\s+([^\n]+)/){
			if ($1 == $arg_num){
				if ($2 eq 'weka'){
					$isweka++;
				}
			}
		}
	}
	close FID_ARG;
	my @arg_grid;
	@arg_grid = @main::cluster_arg_grid if $arg_type eq 'cluster';
	@arg_grid = @main::feature_arg_grid if $arg_type eq 'feature';
	@arg_grid = @main::tt_arg_grid if $arg_type eq 'traintest';
	my @each_grid; my @grid_parms;
	my @grid_position = grep{$arg_grid[$_] =~ m/^$arg_num/g}(0..$#arg_grid);
	my $out_num = 1;
	if(@grid_position){	
		if ($isweka){
			@each_grid = split(m/ /,$arg_grid[$grid_position[0]]);
			for (my $j = 1;$j <= $#each_grid;$j += 2){
				#@grid_parms = (@grid_parms , alalysis_grid_parm($each_grid[$j+1]));
				@grid_parms = alalysis_grid_parm($each_grid[$j+1]);
				$out_num *= scalar @grid_parms;
			}
		}
		else{
			@each_grid = split_grid(' ',$arg_grid[$grid_position[0]]);
			for (@each_grid){$_ =~ s/###//;}
			for (my $j = 1;$j <= $#each_grid;$j += 5){
				#@grid_parms = (@grid_parms , alalysis_grid_parm_3rd($each_grid[$j+4]));
				@grid_parms = alalysis_grid_parm_3rd($each_grid[$j+4]);
				$out_num *= scalar @grid_parms;
			}
		}
	}
	@grid_parms = 'null' if !@grid_parms;
	#return scalar @grid_parms;
	return $out_num;
}

#*******************************************************************
#
# Function Name: show_detail($instance , $attribute , $is4class , $total_job_num)
#
# Description: 
#		Print the details as std outputs
#
# Parameters:
#
# 		$instance: The number of the instances
#		$attribute: The number of the attributes
#		$is4class: The data is for classification or regression
#		$total_job_num: The number of the tasks
#
# Return:
#
#		None
#
#*********************************************************************

sub show_detail{
	my ($instance,$attribute,$is4class,$total_job_num) = @_;
	print "Data infomation:\n";
	print "Instances: $instance\n";
	print "Attributes: $attribute\n";
	print "Data type: for classify\n" if $is4class;
	print "Data type: for regress\n" if !$is4class;
	
	print "Task infomation:\n";
	print "Totaly $total_job_num";
	print " task is " if $total_job_num == 1;
	print " tasks are " if $total_job_num != 1;
	print "expected to be generated and excuted.\n";
}

#*******************************************************************
#
# Function Name: reset_desktop( $experiment_name )
#
# Description: 
#		Clean the related files of specified experiment of PML-desktop.
#
# Parameters:
#
# 		$experimen _name: The name of experiment.
#
# Return:
#
#		None
#
#*********************************************************************

sub reset_desktop{
	#Clean the related files of specified experiment of PML-desktop.
	print "Reset the experiment firstly\n";
	rmtree($_[0]);
	print "Finish reseting\n";
}

#*******************************************************************
#
# Function Name: reset_server()
#
# Description: 
#		Clean the related files and records of specified experiment of PML-server.
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

sub reset_server{
	#Clean the related files and records of specified experiment of PML-server.
	print "Reset the experiment firstly\n";
	print "Cancel jobs...\n";
	#cancel jobs
	my $namec = $main::name . '_train_clu';
	my $namef = $main::name . '_train_fea';
	my $namet = $main::name . '_train_tt';
	my $namea = $main::name . '_train.arff';
	my $namei = $main::name . '_train_inner';
	my $nameo = $main::name . '_train_outer';
	if (-f "bin/cancel_jobs" && -f "$main::prog_dir/results/$main::name/server_wu.log"){
		open(FID_log,"$main::prog_dir/results/$main::name/server_wu.log");
		map{
			$_ =~ s/\s+$//;
			#system("bin/cancel_jobs --name $_");
			my $sys = `bin/cancel_jobs --name $_ 2>&1`;
		}<FID_log>;
		close FID_log;
	}
	print "Complete\n";
	
	print "Check database...\n";
	#check_db
	my $notclean = 1;
	my $db_name = `bin/parse_config db_name`;
	$db_name =~ s/^\s+//;$db_name =~ s/\s+$//;
	my $db_user = `bin/parse_config db_user`;
	$db_user =~ s/^\s+//;$db_user =~ s/\s+$//;
	my $db_host = `bin/parse_config db_host`;
	$db_host =~ s/^\s+//;$db_host =~ s/\s+$//;
	my $db_passwd =  `bin/parse_config db_passwd`;
	$db_passwd =~ s/^\s+//;$db_passwd =~ s/\s+$//;
	
	while($notclean){
		$notclean = 0;
		my $db_purg = `bin/db_purge --one_pass 2>&1`;
		#my $find_str = "SELECT name FROM workunit WHERE name REGEXP \'^$namec\' OR name REGEXP \'^$namef\' OR name REGEXP \'^$namet\'";
		my $find_str = "SELECT name FROM workunit WHERE name REGEXP \'^$main::name\' AND name REGEXP \'_PML_tar_package_\' AND name REGEXP " .'\'tgz$\'';
		my $sys_str = 'echo "use ' . $db_name . ';' . $find_str . '" | mysql ' . "--user=$db_user --password=$db_passwd --host=$db_host";
		my $out = `$sys_str`;
		$out =~ s/^\s+//;$out =~ s/\s+$//;
		if ($out){
			$notclean++;
			my $wait = $#{[split /\n/,$out]} ;
			print $wait . ' workunits are waiting to be canceled, please wait...' ."\n" if $wait > 1;
			print $wait . ' workunit are waiting to be canceled, please wait...' ."\n" if $wait == 1;
			sleep(5);
		}
		else{
			last;
		}
	}
	print "Complete\n";
	
	print "Clean download files...\n";
	#clean download files
	server_clean();
	print "Complete\n";
	
	print "Clean results files...\n";
	#clean results files
	my $rmdir_root = "sample_results";
	my @files = <$rmdir_root/*>;
	while ($#files > -1){
		my $file = pop @files;
		if (-f $file ){
			if ($file =~ /$namec/s || $file =~ /$namef/s || $file =~ /$namet/s ||
			 $file =~ /$namea/s || $file =~ /$namei/s || $file =~ /$nameo/s){
				unlink $file;
			}
			unlink $file if $file =~ /$main::name/s && $file =~ /_PML_tar_package_\d+\.tgz/;
		}
		elsif(-d $file){
			my @subfiles = <$file/*>; 
			if ($#subfiles > -1){
				push @files,@subfiles;
			}
		}
	}
	print "Complete\n";
	
	print "Clean output dir...\n";
	#clean output dir
	$rmdir_root = $main::prog_dir . '/results/' . $main::name;
	@files = <$rmdir_root/*>;
	while ($#files > -1){
		my $file = $files[$#files];
		if (-f $file){
			unlink $file;
			pop @files;
		}
		elsif(-d $file){
			my @subfiles = <$file/*>; 
			if ($#subfiles > -1){
				push @files,@subfiles;
			}
			else{
				rmdir $file;
				pop @files;
			}
		}
	}
	rmdir $rmdir_root;
	print "Complete\n";
	
	print "Clean error log...\n";
	#clean err log
	if (-e 'sample_results/errors'){
		open FID,'sample_results/errors';
		my @lines = <FID>;
		close FID;
		map{$_ = '' if $_ =~ /^$main::name/s && $_ =~ /_PML_tar_package_\d+\.tgz/;}@lines;
		open FID,'>sample_results/errors';
		print FID @lines;
		close FID;
	}
	print "Complete\n";
	print "Finish reseting\n";
}

#*******************************************************************
#
# Function Name: server_clean()
#
# Description: 
#		Clean some data in boinc, clean download files in the folder 'download'
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

sub server_clean{
	#Clean some data in boinc.
	#clean download files
	my $rmdir_root = "download";
#	my $namec = $main::name . '_train_clu';
#	my $namef = $main::name . '_train_fea';
#	my $namet = $main::name . '_train_tt';
#	my $namea = $main::name . '_train.arff';
#	my $namei = $main::name . '_train_inner';
#	my $nameo = $main::name . '_train_outer';
	my @files = <$rmdir_root/*>;
	while ($#files > -1){
		my $file = pop @files;
		if (-f $file ){
#			if ($file =~ /$namec/s || $file =~ /$namef/s || $file =~ /$namet/s
#			 || $file =~ /$namea/s || $file =~ /$namei/s || $file =~ /$nameo/s){
#				unlink $file;
#			}
			unlink $file if $file =~ /$main::name/s && $file =~ /_PML_tar_package_\d+\.tgz/;
		}
		elsif(-d $file){
			my @subfiles = <$file/*>; 
			if ($#subfiles > -1){
				push @files,@subfiles;
			}
		}
	}
	
	#pruge data base
	#system('bin/db_purge --one_pass');
	my $prug_db = `bin/db_purge --one_pass 2>&1`;
}

#*******************************************************************
#
# Function Name: show_help()
#
# Description: 
#		Print the help document
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

sub show_help{
	my ($type) = @_;
	print "useage:\n";
	print "pml_desktop.pl input_script [option]\n" if $type eq 'desktop';
	print "pml_server.pl input_script [option]\n" if $type eq 'server';
	print "\noption:\n";
	print "--help or -h \t Show this help text\n";
	print "--reset \t Reset the experiment first\n";
	print "\nExample:\n";
	print "pml_desktop.pl pml/examples/muti_method_PO_classify\n" if $type eq 'desktop';
	print "pml_server.pl pml/examples/muti_method_PO_classify\n" if $type eq 'server';
	exit;
}

#*******************************************************************
#
# Function Name: uncompressdir($file_name)
#
# Description: 
#		Decompress the .tgz file
#
# Parameters:
#
# 		$file_name: The path of the .tgz file
#
# Return:
#
#		None
#
#*********************************************************************

sub uncompressdir{
	#uncompress files to current folder
	#input file is files.tgz
	my $in = $_[0];
	my $tar = Archive::Tar -> new;
	$tar -> read($in);
	$tar -> extract();
}

1;
__END__