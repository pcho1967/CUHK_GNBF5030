my ($bin, $name, $chrom, $strand, $txStart, $txEnd, $cdsStart, $cdsEnd, $exonCount, $exonStarts, $exonEnds, $score, $name2, $cdsStartStat, $cdsEndStat, $exonFrames);

my $in_file = $ARGV[0]; # input file
my $out_file = $ARGV[1]; # output file

open IN, $in_file;
my %geneindex;
my %mRNAindex;

while (<IN>){
	my @list = split /[\t\n]+/;
		if ($list[12] ne keys%{list}) {$genecounter = $genecounter + 1; $mRNAcounter = 0;}
		if ($list[12] eq keys%{list}) {$genecounter = $genecounter; $mRNAcounter = $mRNAcounter + 1;}	 
		
		$bin = $list[0];
		$name = $list[1];
		$chrom = $list[2];
		$strand = $list[3];
		$txStart = $list[4] + 1;
		$txEnd = $list[5];
		$cdsStart = $list[6] + 1;
		$cdsEnd = $list[7];
		$exonCount = $list[8];
		$exonStarts = $list[9];
		$exonEnds = $list[10];
		$score = $list[11];
		$name2 = $list[12];
		$cdsStartStat = $list[13];
		$cdsEndStat = $list[14];
		$exonFrames = $list[15];
		$geneindex = $genecounter;
		$mRNAindex = $mRNAcointer;

}
close IN;

print @list;