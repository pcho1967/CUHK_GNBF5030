=comment

Write a perl class ”Seq.pm” that define the data structure of a DNA sequence, also provide accessor and mutator methods to get and set the features of a sequence object, such as sequence Id, length, sequence and other features if exist.

=cut

package Seq;

use strict;
use warnings;
use Carp;

sub new {
	my ($class, %arg) = @_;
	return bless {
		_seqId		=> $arg{Id}		|| croak("no sequence id"),
		_seqLength	=> $arg{slength}	|| "????",
		_seqSequence	=> $arg{sequence}	|| "????",
	}, $class;
}


# Accessors to get the sequence information
sub get_seqId       { $_[0] -> {_seqId}       }
sub get_seqLength   { $_[0] -> {_seqLength}   }
sub get_seqSequence { $_[0] -> {_seqSequence} }


# Mutators to set the sequence information
sub set_seqId {
    my ($self, $Id) = @_;
    $self -> {_seqId} = $Id if $Id;
}
sub set_seqLength {
    my ($self, $slength) = @_;
    $self -> {_seqLength} = $slength if $slength;
}
sub set_seqSequence {
    my ($self, $sequence) = @_;
    $self -> {_seqSequence} = $sequence if $sequence;
}


1;
	

