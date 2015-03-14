=comment

Design and implement a perl class ”SeqIO.pm” to read sequence(s) from a fasta file and write sequence(s) to a fasta file.

=cut

package SeqIO;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

# Class data and methods
{
    # A list of all attributes with defaults and read/write/required/noinit properties
    my %_attribute_properties = (
        _filename    => [ '',        'read.write.required'],
        _filedata    => [ [ ],       'read.write.noinit'],
        _date        => [ '',        'read.write.noinit'],
        _writemode   => [ '>',       'read.write.noinit'],
    );
        
    # Global variable to keep count of existing objects
    my $_count = 0;

    # Return a list of all attributes
    sub _all_attributes {
            keys %_attribute_properties;
    }

    # Check if a given property is set for a given attribute
    sub _permissions {
        my($self, $attribute, $permissions) = @_;
        $_attribute_properties{$attribute}[1] =~ /$permissions/;
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
        # E.g. attribute = "_filename",  argument = "filename"
        my($argument) = ($attribute =~ /^_(.*)/);

        # If explicitly given
        if (exists $arg{$argument}) {
            # If initialization is not allowed
            if($self->_permissions($attribute, 'noinit')) {
                croak("Cannot set $argument from read: use set_$argument");
            }
            $self->{$attribute} = $arg{$argument};
        # If not given, but required
        }elsif($self->_permissions($attribute, 'required')) {
            croak("No $argument attribute as required");
        # Set to the default
        }else{
            $self->{$attribute} = $self->_attribute_default($attribute);
        }
    }

    # Read file data
    unless( open( FileIOFH, $self->{_filename} ) ) {
        croak("Cannot open file " .  $self->{_filename} );
    }
    $self->{'_filedata'} = [ <FileIOFH> ];
    $self->{'_date'} = localtime((stat FileIOFH)[9]);
    close(FileIOFH);

}

# Write files
# Called from object, e.g. $obj->write(  );
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
    $self->set_date(scalar localtime((stat FileIOFH)[9]));
    close(FileIOFH);

    return 1;
}

# This takes the place of such accessor definitions as:
#  sub get_attribute { ... }
# and of such mutator definitions as:
#  sub set_attribute { ... }
sub AUTOLOAD {
    my ($self, $newvalue) = @_;

    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\w+)$/);
    
    # Is this a legal method name?
    unless($operation && $attribute) {
        croak "Method name '$AUTOLOAD' is not in the recognized form\n";
    }
    unless(exists $self->{$attribute}) {
        croak "No such attribute '$attribute' exists in the class ", ref($self);
    }

    # AUTOLOAD accessors
    if($operation eq 'get') {
        unless($self->_permissions($attribute, 'read')) {
            croak "$attribute does not have read permission";
        }

        # Turn off strict references to enable symbol table manipulation
        no strict "refs";
        # Install this accessor definition in the symbol table
        *{$AUTOLOAD} = sub {
            my ($self) = @_;
            unless($self->_permissions($attribute, 'read')) {
                croak "$attribute does not have read permission";
            }
            if(ref($self->{$attribute}) eq 'ARRAY') {
                return @{$self->{$attribute}};
            }else{
                return $self->{$attribute};
            }
        };
        # Turn strict references back on
        no strict "refs";

        # Return the attribute value
        # The attribute could be a scalar or a reference to an array
        if(ref($self->{$attribute}) eq 'ARRAY') {
            return @{$self->{$attribute}};
        }else{
            return $self->{$attribute};
        }
    # AUTOLOAD mutators
    }elsif($operation eq 'set') {
        unless($self->_permissions($attribute, 'write')) {
            croak "$attribute does not have write permission";
        }

        # Turn off strict references to enable symbol table manipulation
        no strict "refs";
        # Install this mutator definition in the symbol table
        *{$AUTOLOAD} = sub {
               my ($self, $newvalue) = @_;
            unless($self->_permissions($attribute, 'write')) {
                croak "$attribute does not have write permission";
            }
            $self->{$attribute} = $newvalue;
        };
        # Turn strict references back on
        no strict "refs";

        # Set and return the attribute value
        $self->{$attribute} = $newvalue;
        return $self->{$attribute};
    }
}

# When an object is no longer being used, this will be automatically called
# and will adjust the count of existing objects
sub DESTROY {
    my($self) = @_;
    $self->_decr_count(  );
}

1;
