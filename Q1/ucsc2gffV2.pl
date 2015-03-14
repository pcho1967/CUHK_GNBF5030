my ($bin, $name, $chrom, $strand, $txStart, $txEnd, $cdsStart, $cdsEnd, $exonCount, $exonStarts, $exonEnds, $score, $genename, $cdsStartStat, $cdsEndStat, $exonFrames);

my $in_file = $ARGV[0]; # input file
my $out_file = $ARGV[1]; # output file

my %refgen;

open IN, "gzip -dc ".$in_file." |" or die$!;

	while (<IN>) {
	my @data = split /[\t\n]+/;
		#read refgene,txt record
		$name = $data[1];
		$chrom = $data[2];
		$strand = $data[3];
		$txStart = $data[4];
		$txEnd = $data[5];
		$cdsStart = $data[6];
		$cdsEnd = $data[7];
		$exonCount = $data[8];
		$exonStarts = $data[9];
		$exonEnds = $data[10];
		$score = $data[11];
		$genename = $data[12];
		$cdsStartStat = $data[13];
		$cdsEndStat = $data[14];
		$exonFrames = $data[15];

		$refgen{$genename} = ($chrom."\t".$strand."\t".$txStart."\t".$txEnd."\t".$cdsStart."\t".$cdsEnd."\t".$exonCount."\t".$exonStarts."\t".$exonEnds."\t".$score."\t".$genename."\t".$cdsStartStat."\t".$cdsEndStat."\t".$name);	
	
}
close IN;


my @genelist = sort(keys %refgen);


open OUT, ">", $out_file;

for(my $j = 0; $j < scalar(@genelist); ++$j){
my $mRNAcount = 0;	
	foreach $key (keys %refgen){
	if ($genelist[$j] eq $key){
	$mRNAcount = $mRNAcount + 1;
	my @data1 = split (/[\t\n]+/,$refgen{$key});
		$chrom = $data1[0];
		$strand = $data1[1];
		$txStart = $data1[2];
		$txEnd = $data1[3];
		$cdsStart = $data1[4];
		$cdsEnd = $data1[5];
		$exonCount = $data1[6];
		$exonStarts = $data1[7];
		$exonEnds = $data1[8];
		$score = $data1[9];
		$genename = $data1[10];
		$cdsStartStat = $data1[11];
		$cdsEndStat = $data1[12];
		$name = $data1[13];
		#Gene
		if ($mRNAcount == 1){print OUT (join "\t",$chrom,'.','gene',$txStart,$txEnd,'.',$strand,'.','ID=gene'.($j+1).';Name='.$genelist[$j]."\n");}
		#mRNA
		print OUT (join "\t",$chrom,'.',"mRNA",$txStart,$txEnd,'.',$strand,'.','ID=mRNA'.$mRNAcounter.';Parent=gene'.($j+1).';Name='.$name."\n");
		#Exon & CDS
		my @exon_beg = split /,/, $exonStarts;
 		my @exon_end = split /,/, $exonEnds;
		my $cdsStartUpdate = $cdsStart;
		my $cdsEndUpdate = $cdsEnd;
 		for(my $i = 0; $i < $exonCount; ++$i){
 		print OUT (join "\t", $chrom, '.', 'exon', $exon_beg[$i] + 1, $exon_end[$i], '.', $strand,'.','ID=exon'.($i+1).';Parent=mRNA'.$mRNAcounter.';Name='.$name."\n");

		if ($exon_beg[$i] < $cdsStart
		and $exon_end[$i] > $cdsEnd) {
			$start = $cdsStart;
			$stop  = $cdsEnd;
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}

		if ($exon_beg[$i] < $cdsStart
		and $exon_end[$i] < $cdsEnd) {
			$start = $cdsStart;
			$stop  = $exon_end[$i];
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}
		
		if ($exon_beg[$i] > $cdsStart
		and $exon_end[$i] < $cdsEnd) {
			$start = $exon_beg[$i];
			$stop  = $exon_end[$i];
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcounter.';Parent=mRNA'.$mRNAcounter.';Name='.$name."\n");}

		if ($exon_beg[$i] > $cdsStart
		and $exon_end[$i] > $cdsEnd) {
			$start = $exon_beg[$i];
			$stop  = $cdsEnd;
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}
		

		if ($exon_beg[$i] < $cdsStart
		and $exon_end[$i] >= $cdsEnd) {
			$start = $exon_beg[$i];
			$stop  = $cdsEnd - 1;
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}

		if ($exon_beg[$i] <= $cdsStart
		and $exon_end[$i] > $cdsEnd) {
			$start = $exon_beg[$i];
			$stop  = $cdsEnds-1;
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}

		}
	}
	}
}
close OUT;

