# usage: In linux shell type annotationV1.5.pl <bed filename> <refgene.txt.gz>

use warnings;
use strict;

# import bed file 
open bedFile, $ARGV[0] or die $!;
	my @bed = <bedFile>;
close bedFile;

#open refGene.txt.gz, store gene name, start and end position inti hash
open annoDB, "gzip -dc $ARGV[1]|" or die $!;
	my %anno;
	while(<annoDB>){
		my @fields = split "\t";
				my $refChr = $fields[2];
				my $start = $fields[4];
				my $end = $fields[5];
		$anno{$refChr}{$start."\t".$end}=$fields[12];

	}
close annoDB;

#annotate bed file sequence with refGene gene location
for my $bed (@bed){
	chomp($bed);
	my ($chr, $posstart, $posend) = split "\t", $bed;
	my $chromosome = $chr;
	for my $reflocation (keys %{$anno{$chromosome}}) {
		my ($start, $end) = split "\t", $reflocation;
		my $gene = $anno{$chromosome}{$reflocation};

		#Match whole genomic within or overlap with refgene location	
		if($start <= $posstart && $end >= $posend){
		print ('Input-',"\t",$chr,"\t",$posstart,'-',$posend,"\n",'Output-',"\t",$gene,"\t",$start,'-',$end,"\n");
		next;}
		
		#Match front part in gene location
		if($end > $posstart && $end < $posend){
		print ('Input-',"\t",$chr,"\t",$posstart,'-',$posend,"\n",'Output-',"\t",$gene,"\t",$start,'-',$end,"\n");
		next;}
		
		#Match rear part in gene location
		if($start > $posstart && $start < $posend){
		print ('Input-',"\t",$chr,"\t",$posstart,'-',$posend,"\n",'Output-',"\t",$gene,"\t",$start,'-',$end,"\n");
		next;}

}
}

