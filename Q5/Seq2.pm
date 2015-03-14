=comment

Write a perl class ”Seq.pm” that define the data structure of a DNA sequence, also provide accessor and mutator methods to get and set the features of a sequence object, such as sequence Id, length, sequence and other features if exist.

Try use AUTOLOAD instead of individual accessor and mutator

=cut

package Seq2;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

sub new {
	my ($class, %arg) = @_;
	return bless {
		_seqId		=> $arg{Id}		|| croak("no sequence id"),
		_seqLength	=> $arg{slength}	|| "????",
		_seqSequence	=> $arg{sequence}	|| "????",
	}, $class;
}


sub AUTOLOAD {
    my ($self, $newvalue) = @_;

    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\w+)$/);
    
    # Is this a legal method name?
    unless($operation && $attribute) {
        croak "Method name $AUTOLOAD is not in the recognized form (get|set)_attribute\n";
    }
    unless(exists $self->{$attribute}) {
        croak "No such attribute '$attribute' exists in the class ", ref($self);
    }

    # Turn off strict references to enable "magic" AUTOLOAD speedup`
    no strict 'refs';

    # AUTOLOAD accessors
    if($operation eq 'get') {
        # define subroutine
        *{$AUTOLOAD} = sub { shift->{$attribute} };

    # AUTOLOAD mutators
    }elsif($operation eq 'set') {
        # define subroutine
        *{$AUTOLOAD} = sub { shift->{$attribute} = shift; };

        # set the new attribute value
        $self->{$attribute} = $newvalue;
    }

    # Turn strict references back on
    use strict 'refs';

    # return the attribute value
    return $self->{$attribute};
}

1;
	

