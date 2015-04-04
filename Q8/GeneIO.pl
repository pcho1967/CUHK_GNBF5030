use strict;
use warnings;
use GeneIO;
use UCSCGene;

# syntax SeqIO.pl InputFile OutFile Action
my $obj = GeneIO->new(  );
my $gene = UCSCGene->new();
my $in_file = $ARGV[0];
my $out_file = $ARGV[1];
my $action = $ARGV[2];#Action:- New; Append
my %genelist;
my @newdataset;
my $j = 0;

$obj->read(
  filename => $in_file
);

my @newdata = $obj->get_filedata;
$obj->set_filedata( \@newdata );

# extract each UCSC record into individual UCSCGene object
foreach (@newdata) {
my $i = shift @newdata;
$j = $j + 1;
my @data = split /[\t\n]+/;
  $genelist{$j} = UCSCGene->new(
		name => $data[1], 
		chromosome => $data[2],
		strand	=> $data[3],
		genestart => $data[4],
		geneend	=> $data[5],
		cdss => $data[6],
		cdse => $data[7],
		exonc => $data[8],
		exons => $data[9],
		exone => $data[10],
		score => $data[11],
		genename => $data[12],
		cdsss => $data[13],
		cdses =>$data[14],
		exonf => $data[15]);

}

print "The input file name is ", $obj->get_filename, "\n";

#build new data file for save with genename, txStart, txEnd
for my $key (keys %genelist){
my $record =  ($genelist{$key} -> get_genename)."\t".($genelist{$key} -> get_txStart)."\t".($genelist{$key} -> get_txEnd)."\n";
push (@newdataset, $record);
next;
}

#foreach (@newdataset){
#print $_;
#print scalar (@newdataset);
#}

$obj -> set_filedata (\@newdataset);

if ($action eq "New"){
	$obj->write(filename => $out_file);
}
elsif ($action eq "Append"){
	print "Appending to the new file \n";
	$obj->write(filename => $out_file, writemode => '>>');
}
else{
}

my $file2 = GeneIO->new(  );
$file2->read(
  filename => $out_file
);

print "The output file name is ", $file2->get_filename, "\n";

