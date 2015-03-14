=comment

Question 6: Write a complete version of ”Gene.pm” that describe the multi-exon structure for a human gene, also provide accessor and mutator methods to get and set the features of a Gene object, such as the chromosome Id, the start and end position, cds start position and end position, and other features.

Gene model refer to refgene.gz from UCSC

=cut

package Gene;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

# Design Gene class whihc refer to refgene,gz format
sub new {
        my ($class, %arg) = @_;
        return bless {
                _name       	=> $arg{name}        	|| croak("no name"),
                _chromosome	=> $arg{chromosome}	|| "????",
		_strand		=> $arg{strand}		|| "????",
		_txStart	=> $arg{txStart}	|| "????",
		_txEnd		=> $arg{txEnd}		|| "????",
		_cdsStart	=> $arg{cdsStart}	|| "????",
		_cdsEnd		=> $arg{csdEnd}		|| "????",
		_exonCount	=> $arg{exonCount}	|| "????",
		_exonStart	=> $arg{exonStart}	|| "????",
		_exonEnds	=> $arg{exonEnds}	|| "????",
		_score		=> $arg{score}		|| "????",
		_geneName	=> $arg{geneName}	|| "????",
		_cdsStartStat	=> $arg{cdsStartStat}	|| "????",
		_cdsEndStat	=> $arg{cdsEndStat}	|| "????",
		_exonFrames	=> $arg{exonFrames}	|| "????",		
	}, $class;
}

# Use AUTOLOAD to create accessor and mutator method
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

1;


