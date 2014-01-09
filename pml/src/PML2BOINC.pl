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

#integrate PML into BOINC
#
#modify and backup project.xml
#modify and backup config.xml
#copy templetes
#add links
#rename the private key
#copy and sign apps

use strict;
use warnings;
use File::Copy;
#use Cwd;

my ($project_root) = @ARGV;
print "Initializing...\n";
print "Check the folders which are necessary...\n";

my $projectxml_root = $project_root;
print "Detected project.xml in folder $projectxml_root.\n" if -f $projectxml_root.'/project.xml';
while(!-f $projectxml_root.'/project.xml'){
	print "Can not detect project.xml in path\n",$projectxml_root,"\n","Please input the folder path which contain the file project.xml:\n";
	$projectxml_root = <STDIN>;
	$projectxml_root =~ s/\s+$//;
	$project_root = $projectxml_root;
}


my $configxml_root = $project_root;
print "Detected config.xml in folder $configxml_root.\n" if -f $configxml_root.'/config.xml';
while(!-f $configxml_root.'/config.xml'){
	print "Can not detect config.xml in path\n",$configxml_root,"\n","Please input the folder path which contain the file config.xml:\n";
	$configxml_root = <STDIN>;
	$configxml_root =~ s/\s+$//;
	$project_root = $configxml_root;
}

my $privite_key_path;
$privite_key_path = $project_root.'/keys/code_sign_private' if -f $project_root.'/keys/code_sign_private';
$privite_key_path = $project_root.'/keys/code_sign_private_old' if 
-f $project_root.'/keys/code_sign_private_old' && !-f $project_root.'/keys/code_sign_private';
print "Detected private key with path $privite_key_path.\n" if -f $privite_key_path;
while(!-f $privite_key_path){
	print "Can not detect private key in path\n",$privite_key_path,"\n","Please input the path of the file (not folder) code_sign_private:\n";
	$privite_key_path = <STDIN>;
	$privite_key_path =~ s/\s+$//;
}

my $pml_root;
map{$pml_root = $_ if -d "$_/src" && -d "$_/lib" && -d "$_/config" && -d "$_/web"}('./','../');
print "Detected path of pml at $pml_root\n" if -d "$pml_root/src" && -d "$pml_root/lib" && -d "$pml_root/config" && -d "$pml_root/web";
while (!-d "$pml_root/src" || !-d "$pml_root/lib" || !-d "$pml_root/config" || !-d "$pml_root/web"){
	print "Can not detect the folder where PML located, please input it manually:\n";
	$pml_root = <STDIN>;
	$pml_root =~ s/\s+$//;
}

my $temp_root = "$pml_root/server/templates";
print "Detected folder templates in $temp_root.\n" if -d $temp_root;
while(!-d $temp_root){
	print "Can not detect the templates folder which should be located at the $pml_root/server/templates, please input the path manually:\n";
	$temp_root = <STDIN>;
	$temp_root =~ s/\s+$//;
}

my $app_root = "$pml_root/server/apps";
print "Detected folder apps.\n" if -d $app_root;
while(!-d $app_root){
	print "Can not detect the apps folder which should be located at the $pml_root/server/apps, please input the path manually:\n";
	$app_root = <STDIN>;
	$app_root =~ s/\s+$//;
}
###############################################################################################33
#Modify and backup project.xml
###############################################################################################33
print "Begin to modify and backup the project.xml...\n";
if (-f $projectxml_root.'/project.xml.old'){
	copy $projectxml_root.'/project.xml.old',$projectxml_root.'/project.xml.old' 
}
else{
	rename $projectxml_root.'/project.xml',$projectxml_root.'/project.xml.old';
}
print "project.xml has been backed up as project.xml.old";
open(FID,"$projectxml_root/project.xml.old");
my @lines = <FID>;
close FID;
for (@lines){
	if ($_ =~ /\<\/boinc\>/){
		$_ = '    <app>
        <name>pml_tar</name>
        <user_friendly_name>Sent compressed tasks to Clients</user_friendly_name>
    </app>
   
</boinc>';
	}
}
open(FID,">$projectxml_root/project.xml");
print FID @lines;
close FID;
print "Complete\n\n";
@lines=();

print "Initializtion complete\n";

###############################################################################################33
#Modify and backupconfig.xml
###############################################################################################33
print "Begin to modify and backup the config.xml...\n";
if (-f $configxml_root.'/config.xml.old'){
	copy $configxml_root.'/config.xml.old',$configxml_root.'/config.xml';
}
else{
	rename $configxml_root.'/config.xml',$configxml_root.'/config.xml.old';
}
print "config.xml has been backed up as config.xml.old";
open(FID,"$configxml_root/config.xml.old");
@lines = <FID>;
close FID;
for (@lines){
	if ($_ =~ /\<\/config\>/){
		$_ = '
    <prefer_primary_platform> 1 </prefer_primary_platform>
  </config>
'."\n";
	}
	if ($_ =~ /\<\/daemons\>/){
		$_='    
    <daemon>
      <cmd>db_purge -d 3 </cmd>
    </daemon>

    <daemon>
      <cmd>sample_trivial_validator1 -d 3 --app pml_tar</cmd>
    </daemon>

    <daemon>
      <cmd>sample_assimilator1 -d 3 --app pml_tar</cmd>
    </daemon>

  </daemons>'."\n";
	}
}
open(FID,">$configxml_root/config.xml");
print FID @lines;
close FID;
print "Complete\n\n";
###############################################################################################33
#Copy the templates
###############################################################################################33
print "Copy files from $temp_root to $project_root/templates\n";
my @files = <$temp_root/*>;
for (@files){
	copy $_,"$project_root/templates" || die $!;
}
print "complete\n\n";

###############################################################################################33
#Add some soft links
###############################################################################################33
print "Make links for validator and assimilator\n";
map{
	system 'ln -sf sample_trivial_validator ' . $project_root . '/bin/sample_trivial_validator' . $_;
	system 'ln -sf sample_assimilator ' . $project_root . '/bin/sample_assimilator' . $_;
}1;
print "complete\n\n";
###############################################################################################33
#Rename the private key
###############################################################################################33
if ($privite_key_path eq $project_root.'/keys/code_sign_private'){
	print "Change the name of private key...\n" ;
	rename $project_root.'/keys/code_sign_private',$project_root.'/keys/code_sign_private_old';
	$privite_key_path = $project_root.'/keys/code_sign_private_old';
	print "The name of private key has been changed to code_sign_private_old.\n\n";
}
else{
	print "There is no necessary to change the name of private key.\n"
}
###############################################################################################33
#Copy and sign apps
###############################################################################################33
print "Begin to copy and sign apps ...\n";
opendir(DIR,$app_root);
my @appfiles = readdir DIR;
@appfiles = grep{$_ ne '.' && $_ ne '..'}@appfiles;
closedir DIR;
while ($#appfiles > -1){
	my $appfile = pop @appfiles;
	if (-d $app_root . '/' . $appfile){
		mkdir $project_root.'/apps/'.$appfile if !-d $project_root.'/apps/'.$appfile;
		opendir(SDIR,$app_root . '/' . $appfile);
		my @subappfiles = readdir SDIR;
		closedir SDIR;
		@subappfiles = grep{$_ ne '.' && $_ ne '..'}@subappfiles;
		map{$_ = $appfile . '/' . $_}@subappfiles;
		push @appfiles,@subappfiles;
	}
	if (-f $app_root . '/' . $appfile){
		
		copy $app_root . '/' . $appfile,$project_root.'/apps/'.$appfile || die $!;
		
		system 'chmod a+x ' . $project_root.'/apps/'.$appfile if $appfile =~ /\.pl$/;
		next if $appfile =~ /version/i;
		my $cmd_str = $project_root.'/bin/crypt_prog -sign '.$project_root.'/apps/'.$appfile.' '.$privite_key_path.' > '.$project_root.'/apps/'.$appfile.'.sig';
		system($cmd_str);
	}
}

print 'Complete!'."\n";

print 'Begin to copy components to '.$project_root." ...\n";
mkdir $project_root.'/pml' if !-d $project_root.'/pml';
opendir(DIR,$pml_root);
my @pmlfiles = readdir DIR;
@pmlfiles = grep{$_ ne '.' && $_ ne '..'}@pmlfiles;
#@pmlfiles = () if $pml_root =~ /$project_root\/?pml\/?$/s;
#print "The files is already in the project root\n" if $pml_root =~ /$project_root\/?pml\/?$/s;;
closedir DIR;
while ($#pmlfiles > -1){
	my $pml_file = pop @pmlfiles;
	next if $pml_file eq 'server';
	if (-d $pml_root.'/'.$pml_file){
		next if $pml_file =~ /results/ || $pml_file =~ /wus/; 
		mkdir $project_root.'/pml/'.$pml_file if !-d $project_root.'/pml/'.$pml_file;
		opendir(SDIR,$pml_root . '/' . $pml_file);
		my @subpmlfiles = readdir SDIR;
		closedir SDIR;
		@subpmlfiles = grep{$_ ne '.' && $_ ne '..'}@subpmlfiles;
		map{$_ = $pml_file . '/' . $_}@subpmlfiles;
		push @pmlfiles,@subpmlfiles;
	}
	if (-f $pml_root.'/'.$pml_file){
		copy $pml_root.'/'.$pml_file , $project_root.'/pml_server.pl' if $pml_file =~ /pml_server\.pl/;
		system 'chmod a+x '.$project_root.'/pml_server.pl' if $pml_file =~ /pml_server\.pl/;
		copy $pml_root.'/'.$pml_file , $project_root.'/pml/'.$pml_file;
		system 'chmod a+x '.$project_root.'/pml/'.$pml_file if $pml_file =~ /\.pl$/;
	}
}

print "Complete!","\n";
print "Integrate PML into BOINC project completely.\n";
print "Please execute \n bin/xadd \nand \n bin/update_versions in $project_root manually after this installation"."\n";






