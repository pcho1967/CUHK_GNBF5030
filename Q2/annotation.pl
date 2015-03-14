use warnings;
use strict;

open snpFile, $ARGV[0] or die $!;
	my @snp = <snpFile>;
close snpFile;

open annoDB, $ARGV[1] or die $!;
	my %anno;
	while(<annoDB>){
		my @fields = split "\t";
				my $refChr = $fields[2];
				my $start = $fields[4];
				my $end = $fields[5];
		$anno{$refChr}{$start."\t".$end}=$fields[12];

	}
close annoDB;

for my $snp (@snp){
	chomp($snp);
	my ($chr, $pos, $end) = split "\t", $snp;
	my $chromosome = $chr;
	for my $reflocation (keys %{$anno{$chromosome}}) {
		my ($start, $end) = split "\t", $reflocation;
		my $gene =$anno{$chromosome}{$reflocation};
		if($pos >= $start && $pos <= $end){
		print $chr, "\t", $pos, "\t", $end, "\t", $gene,"\n";
	}
}
}

