#Design and implement a perl class ”SeqIO.pm” to read sequence(s) from a fasta file and write sequence(s) to a fasta file.
package SeqIO;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

{
    my %_attribute_properties = (
        _filename    => [''],
        _filedata    => [[ ]],
        _writemode   => ['>'],
    );
        
    my $_count = 0;

   sub _all_attributes {
            keys %_attribute_properties;
    }

    # Return the default value for a given attribute
    sub _attribute_default {
            my($self, $attribute) = @_;
        $_attribute_properties{$attribute}[0];
    }

    # Manage the count of existing objects
    sub get_count {
        $_count;
    }
    sub _incr_count {
        ++$_count;
    }
    sub _decr_count {
        --$_count;
    }
}

# The constructor method
sub new {
    my ($class, %arg) = @_;

    # Create a new object
    my $self = bless {  }, $class;

    $class->_incr_count(  );
    return $self;
}


# Called from object, e.g. $obj->read(  );
sub read {
    my ($self, %arg) = @_;

    # Set attributes
    foreach my $attribute ($self->_all_attributes(  )) {
        my($argument) = ($attribute =~ /^_(.*)/);
        if (exists $arg{$argument}) {
            $self->{$attribute} = $arg{$argument};
        }else{
            $self->{$attribute} = $self->_attribute_default($attribute);
        }
    }

    # Read file data
    unless( open( FileIOFH, $self->{_filename} ) ) {
        croak("Cannot open file " .  $self->{_filename} );
    }
    $self->{'_filedata'} = [ <FileIOFH> ];
    close(FileIOFH);

}

# Write files e.g. $obj->write(  );
sub write {
    my ($self, %arg) = @_;

    foreach my $attribute ($self->_all_attributes(  )) {
        # E.g. attribute = "_filename",  argument = "filename"
        my($argument) = ($attribute =~ /^_(.*)/);

        # If explicitly given
        if (exists $arg{$argument}) {
            $self->{$attribute} = $arg{$argument};
        }
    }
    
    unless( open( FileIOFH, $self->get_writemode . $self->get_filename ) ) {
        croak("Cannot write to file " .  $self->get_filename);
    }
    unless( print FileIOFH $self->get_filedata ) {
        croak("Cannot write to file " .  $self->get_filename);
    }
    close(FileIOFH);

    return 1;
}

sub AUTOLOAD {
    my ($self, $newvalue) = @_;
    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\w+)$/);
    unless($operation && $attribute) {
        croak "Method name '$AUTOLOAD' is not in the recognized form\n";
    }
    unless(exists $self->{$attribute}) {
        croak "No such attribute '$attribute' exists in the class ", ref($self);
    }
    if($operation eq 'get') {
        no strict "refs";
        *{$AUTOLOAD} = sub {
            my ($self) = @_;
            if(ref($self->{$attribute}) eq 'ARRAY') {
                return @{$self->{$attribute}};
            }else{
                return $self->{$attribute};
            }
        };
        no strict "refs";

        if(ref($self->{$attribute}) eq 'ARRAY') {
            return @{$self->{$attribute}};
        }else{
            return $self->{$attribute};
        }

    }elsif($operation eq 'set') {
        no strict "refs";
        *{$AUTOLOAD} = sub {
               my ($self, $newvalue) = @_;
            $self->{$attribute} = $newvalue;
        };
        no strict "refs";

        $self->{$attribute} = $newvalue;
        return $self->{$attribute};
    }
}


sub DESTROY {
    my($self) = @_;
    $self->_decr_count(  );
}

1;