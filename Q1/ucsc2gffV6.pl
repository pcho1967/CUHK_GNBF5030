=comment

Gene mode cardinality between fields
Chromosome 1 to n GeneName
GeneName 1 to n mRNA isoform
mRNA 1 to n Exon and CDS
CDS partial or completely overlap with exon start and end lcoation

Record in GFF format is different as in UCSC which each record is a distinct CDS
Record in UCSC id in mRNA iosform level with compress on exon and CDS details
Thus we need to loop out exon infromation from UCSC to GFF
The indexing on Gene to Exon then CDS are in numeric which is missing in UCSC
Therefore we creat a hash with key as chromosome and genename and mRNA isoform count and read refgen file into the hash and loop out each exon and CDS location and write as GFF format

=cut

use strict;
use warnings;

#setup variables as in UCSC file
my ($bin, $name, $chrom, $strand, $txStart, $txEnd, $cdsStart, $cdsEnd, $exonCount, $exonStarts, $exonEnds, $score, $genename, $cdsStartStat, $cdsEndStat, $exonFrames, $start, $stop);

my $in_file = $ARGV[0]; # input file
my $out_file = $ARGV[1]; # output file

# setup two hash sile to store gene index and mRNA index for GFF transformation
my %geneindex;
my %RNAindex;
# initialized the value in %genindex and % RNAindex hash as 1 
my $genecount = 0;
my $mRNAcount = 0;

#read in refgen file into %refgen has with key as chromosome + genename + mRNA isoform count
open IN, "gzip -dc ".$in_file." |" or die$!;
open OUT, ">", $out_file;

	while (<IN>) {
	my @data = split /[\t\n]+/;
#read refgene file and store as hash value record
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
# if new gene read in increment genecount +1 and store in %geneindex
		if (!exists($geneindex{$chrom}{$genename})){
		$genecount = $genecount + 1;
		$geneindex{$chrom}{$genename} = $genecount;
		}
# if old gene read resue genecount and store in %geneindex
		if (exists($geneindex{$chrom}{$genename})){
		$genecount = $geneindex{$chrom}{$genename};
		} 
# if first mRNA record is read set mRNA isoform counter is 1 and store in %RNAindex
		if (!exists($RNAindex{$chrom}{$genename}{$name})){
		$mRNAcount = 1;
		$RNAindex{$chrom}{$genename}{$name} = $mRNAcount;
		}
# hask key is unique and value will be overwirte during key duplaiction. Chr>1-n>gene>1-n>mRNA>1-n>exon/CDS
# if gene exist within hash recad as mENA isoform with mRNAcount + 1 and add as hash key and store in %RNAindex
		if (exists($RNAindex{$chrom}{$genename}{$name})){
			$mRNAcount = $RNAindex{$chrom}{$genename}{$name};
			$mRNAcount = $mRNAcount + 1;
			$RNAindex{$chrom}{$genename}{$name} = $mRNAcount;
		}

# Write Gene information
		print OUT (join "\t",$chrom,'.','gene',$txStart,$txEnd,'.',$strand,'.','ID=gene'.$genecount.';Name='.$genename."\n");
# write mRNA information
		print OUT (join "\t",$chrom,'.',"mRNA",$txStart,$txEnd,'.',$strand,'.','ID=mRNA'.$mRNAcount.';Parent=gene'.$genecount.';Name='.$name."\n");

# write Exon  
		my @exon_beg = split /,/, $exonStarts;
 		my @exon_end = split /,/, $exonEnds;
		my $cdsStartUpdate = $cdsStart;
		my $cdsEndUpdate = $cdsEnd;
# use for loop to write all exon start and end location in separate record in GFF and determine CDS location in simultaneously
 		for(my $i = 0; $i < $exonCount; ++$i){
 		print OUT (join "\t", $chrom, '.', 'exon', $exon_beg[$i] + 1, $exon_end[$i], '.', $strand,'.','ID=exon'.($i+1).';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");

# check CDS is partially or completely overlap with exon and determine the CDS start and end location
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
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}

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
			$stop  = $cdsEnd-1;
		print OUT (join "\t", $chrom, '.', 'CDS', $start, $stop, '.', $strand,'.','ID=CDS'.$mRNAcount.';Parent=mRNA'.$mRNAcount.';Name='.$name."\n");}

		}

}

close OUT;
close IN;



