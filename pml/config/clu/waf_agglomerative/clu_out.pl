open FID,'out_clu.txt';
while (my $line = <FID>){
	print $line if $line !~ /^\@/ && $line !~ /^\s+$/;
}
close FID