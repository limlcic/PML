open FID,'out_tt.txt';
while (my $line = <FID>){
	print $line if $line !~ /^\@/ && $line !~ /^\s+$/;
}
close FID