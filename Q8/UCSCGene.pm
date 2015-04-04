#Design and implement a perl class "GeneIO.pm" to read gene entries from a UCSC gene file and write gene entries to a UCSC gene file.
package UCSCGene;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

my $_count = 0;

sub new {
	my ($class, %arg) = @_;
	my $self = bless {
		_name => $arg{name}	|| "????",
		_chrom => $arg{chromosome}	|| "????",
		_strand => $arg{strand}	|| "????",
		_txStart => $arg{genestart}	|| "????",
		_txEnd => $arg{geneend}	|| "????",
		_cdsStart => $arg{cdss}	|| "????",
		_cdsEnd	=> $arg{cdse}	|| "????",
		_exonCount => $arg{exonc}	|| "????",
		_exonStarts => $arg{exons}	|| "????",
		_exonEnds => $arg{exone}	|| "????",
		_score => $arg{score}	|| "????",
		_genename => $arg{genename}	|| "????",
		_cdsStartStat => $arg{cdsss}	|| "????",
		_cdsEndStat => $arg{cdses}	|| "????",
		_exonFrames => $arg{exonf}	|| "????",
		}, $class;
		$class->_incr_count(  );
		return $self;
}

sub get_count {
        $_count;
    }
sub _incr_count {
        ++$_count;
    }
sub _decr_count {
        --$_count;
    }


sub AUTOLOAD {
    my ($self, $newvalue) = @_;
    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\w+)$/);
    unless($operation && $attribute) {
        croak "Method name $AUTOLOAD is not in the recognized form (get|set)_attribute\n";
    }
    unless(exists $self->{$attribute}) {
        croak "No such attribute '$attribute' exists in the class ", ref($self);
    }
    no strict 'refs';
    if($operation eq 'get') {
        *{$AUTOLOAD} = sub { shift->{$attribute} };
    }elsif($operation eq 'set') {
        *{$AUTOLOAD} = sub { shift->{$attribute} = shift; };
        $self->{$attribute} = $newvalue;
    }
    use strict 'refs';
    return $self->{$attribute};
}

sub DESTROY {
    my($self) = @_;
    $self->_decr_count(  );
}

1;
	

