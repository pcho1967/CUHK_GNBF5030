=comment

Question 6: Write a complete version of ”Gene.pm” that describe the multi-exon structure for a human gene, also provide accessor and mutator methods to get and set the features of a Gene object, such as the chromosome Id, the start and end position, cds start position and end position, and other features.

Gene model refer to refgene.gz from UCSC

=cut


# Test the Seq module with accessor and mutator

use strict;
use warnings;

use Gene;

print "Object 1:\n\n";

# New first gene object as $obj1
my $obj1 = Gene->new(
        name		=> "NM_005228",
        chromosome	=> "chr7",
        strand		=> "+",
	txStart		=> "55086724",
	txEnd		=> "55275031",
	cdsStart	=> "55086970",
	cdsEnd		=> "55273310",
	exonCount	=> "28",
	geneName	=> "EGFR",
		
); 

# use accessor to get $obj1 value and print
print "Name:\t".$obj1->get_name, "\n";
print "Chromosome:\t".$obj1->get_chromosome, "\n";
print "Strand:\t".$obj1->get_strand, "\n";
print "Gene name:\t".$obj1->get_geneName, "\n";
print "Score:\t".$obj1->get_score, "\n";
print "Exon start:\t".$obj1->get_exonStart, "\n";
print "Exon end:\t".$obj1->get_exonEnds, "\n";
print "\n\n";

# use mutator to set $obj1 exonStart and exonEnds attribute
$obj1->set_exonStart("55083724,55209978,55210997,55214298");
$obj1->set_exonEnds("55087058,55210130,55214433,55219055");

print "Name:\t".$obj1->get_name, "\n";
print "Chromosome:\t".$obj1->get_chromosome, "\n";
print "Strand:\t".$obj1->get_strand, "\n";
print "Gene name:\t".$obj1->get_geneName, "\n";
print "Score:\t".$obj1->get_score, "\n";
print "Exon start:\t".$obj1->get_exonStart, "\n";
print "Exon end:\t".$obj1->get_exonEnds, "\n";
print "\n\n";


