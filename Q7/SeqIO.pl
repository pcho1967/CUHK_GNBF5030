use strict;
use warnings;
use SeqIO;

# syntax SeqIO.pl InputFile OutFile Action
my $obj = SeqIO->new(  );
my $in_file = $ARGV[0];
my $out_file = $ARGV[1];


$obj->read(
  filename => $in_file
);

print "The input file name is ", $obj->get_filename, "\n";
print "The contents of the file are:\n", $obj->get_filedata, "\n";

my @newdata = $obj->get_filedata;
$obj->set_filedata( \@newdata );

print "Writing a new file \n";
$obj->write(filename => $out_file);

print "Appending to the new file \n";
$obj->write(filename => $out_file, writemode => '>>');

my $file2 = SeqIO->new(  );

$file2->read(
  filename => $out_file
);

print "The file name is ", $file2->get_filename, "\n";
print "The contents of the file are:\n", $file2->get_filedata, "\n";
