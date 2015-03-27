=comment
http://doc.bioperl.org/bioperl-live/Bio/Tools/SeqStats.html

Use an appropriate Bioperl module to count the number of bases and the frequency of codons in a DNA sequence file.

= Bio::Tools::SeqStats

Bio::Tools::SeqStats is a lightweight object for the calculation of simple statistical and numerical properties of a sequence. By "lightweight" I mean that only "primary" sequences are handled by the object. The calling script needs to create the appropriate primary sequence to be passed to SeqStats if statistics on a sequence feature are required. Similarly if a codon count is desired for a frame-shifted sequence and/or a negative strand sequence, the calling script needs to create that sequence and pass it to the SeqStats object.

=cut

use lib '/usr/local/src/BioPerl-1.6.923/Bio/';
use lib '/home/pcho/perl5/perlbrew/perls/perl-5.20.1/lib/BioPerl-1.6.923/';

use Bio::Seq;
use Bio::Tools::SeqStats;


$seqobj = Bio::PrimarySeq->new(-seq      => 'ACTGTGGCGTCAACTG',
                               -alphabet => 'dna',
                               -id       => 'test');
$seq_stats  =  Bio::Tools::SeqStats->new(-seq => $seqobj);

# obtain a hash of counts of each type of monomer
# (i.e. amino or nucleic acid)
print "\nMonomer counts using statistics object\n";
$seq_stats  =  Bio::Tools::SeqStats->new(-seq=>$seqobj);
 $hash_ref = $seq_stats->count_monomers();  # e.g. for DNA sequence
foreach my $base (sort keys %$hash_ref) {
    print "Number of bases of type ", $base, "= ", 
       $$hash_ref{$base},"\n";
}


# obtain hash of counts of each type of codon in a nucleic acid sequence
print "\nCodon counts using statistics object\n";
 $hash_ref = $seq_stats-> count_codons();  # for nucleic acid sequence
foreach $base (sort keys %$hash_ref) {
    print "Number of codons of type ", $base, "= ", 
       $$hash_ref{$base},"\n";
}
 
#  or
print "\nCodon counts without statistics object\n";
 $hash_ref = Bio::Tools::SeqStats->count_codons($seqobj);
foreach $base (sort keys %$hash_ref) {
    print "Number of codons of type ", $base, "= ", 
       $$hash_ref{$base},"\n";
}
