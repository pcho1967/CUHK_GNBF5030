=comment

Write a perl class ”Seq.pm” that define the data structure of a DNA sequence, also provide accessor and mutator methods to get and set the features of a sequence object, such as sequence Id, length, sequence and other features if exist.

=cut


# Test the Seq module with accessor and mutator

use strict;
use warnings;

use Seq2;

print "Object 1:\n\n";

# New first sequence object as $obj1
my $obj1 = Seq2->new(
        Id          => "001",
        slength     => "10",
        sequence    => "ATGCATGCAA",
); 

# use accessor to get $obj1 value and print
print $obj1->get_seqId, "\n";
print $obj1->get_seqLength, "\n";
print $obj1->get_seqSequence, "\n\n";

# use mutator to set $obj1.sequence and print
$obj1->set_seqSequence("AAAAAA");
$obj1->set_seqLength("6");

print $obj1->get_seqId, "\n";
print $obj1->get_seqLength, "\n";
print $obj1->get_seqSequence, "\n\n";
