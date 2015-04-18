#Complete subroutine plot gene and write a Perl program to plot the structure of human genes using SVG.

use strict;
use warnings;
use GeneIO;
use UCSCGene;
use SVG;
use Bio::SeqIO;

my $obj = GeneIO->new(  );
my $gene = UCSCGene->new();
my $in_file = $ARGV[0];
#my $out_file = $ARGV[1];
#my $action = $ARGV[2];#Action:- New; Append
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
		start => $data[4],
		end	=> $data[5],
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


my $svg = SVG->new('width', 1024,'height', 768);
my $tick_unit= 10000; # 10kb a tick
my $left_margin_width = 50;
# the start of the genomic position on the plot
my $genomic_position_start = 1960000;
# the end of the genomic position on the plot
my $genomic_position_end = 2150000;
my $scale = 1000; # 1kb per pixel
my @genes = @newdataset;
my $y = 10; # the y coordiates to start the plot of genes

for my $key (keys %genelist){
my $height = plot_genes($svg, ($genelist{$key} -> get_txStart), ($genelist{$key} -> get_txEnd), $scale, $left_margin_width, ($genelist{$key} -> get_genename), $y);
#my $record =  ($genelist{$key} -> get_genename)."\t".($genelist{$key} -> get_txStart)."\t".($genelist{$key} -> get_txEnd)."\n";
#push (@newdataset, $record);
next;
}
#my $height = plot_genes($svg, ($genelist{$key} -> get_txStart), ($genelist{$key} -> get_txEnd), $scale, $left_margin_width, ($genelist{$key} -> get_genename), $y);

sub plot_genes {
my $svg =shift;
# collect parameters ...
# sort genes by the start position ...
# plot each gene, if a gene overlap with the previous one, plot it on a new row
my $row = 0;
my $row_skip = 50; # number of pixels per row
my %row_end; # keep the end position of the previous gene in each row
foreach my $g (@genes) {
# determine which row to plot
my $k = -1;
for (my $i =0; $i <= $row; $i++) {
if (not defined $row_end{$i}) { # no gene at row i
$k = $i;
} elsif ($g->get_txStart > $row_end{$i}) {
$k = $i;
} else {# nothing to do here, goto the next row}
}
if ($k == -1) {$row++; $k = $row;}
}
# plot gene
my $tmp_y = $y + $k * $row_skip;
plot_gene($svg, ($genelist{$key} -> get_txStart), ($genelist{$key} -> get_txEnd), $scale, $left_margin_width, $g, $tmp_y);
#update the end postion of the k-th row
$row_end{$k} = $g->get_txEnd;
}
return $row_skip * ($row + 1); # the total height of gene track
}

=comment
my $svg = SVG->new('width', 1024,'height', 768);
# the start of the genomic position on the plot
my $genomic_position_start = 1960000;
# the end of the genomic position on the plot
my $genomic_position_end = 2150000;
my $scale = 100; # 1kp per pixel
my $tick_unit= 10000; # 10kb a tick
my $left_margin_width = 50;
my $y = 50; # the y coordiates to add the ruler
plot_ruler($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $y, $tick_unit);
=cut

open OUT,">out.svg";
print OUT $svg->xmlify();
close OUT;


sub plot_ruler {
	my $svg = shift;
# collect parameters ...
	my $length = $genomic_position_end - $genomic_position_start;
	my $ticN = 0;
	if ($length % $tick_unit == 0) {$ticN = $length/$tick_unit;} 
	else {$ticN = ($length/$tick_unit)+1;}
	print $ticN;

	my $x1 = $left_margin_width; my $x2 = ($left_margin_width) + int($length/$scale) ; 
		$svg->line('x1',$x1,'y1',$y,'x2',$x2,'y2',$y,'stroke','black','stroke-width',2);
		
	for (my $i=0; $i <= $ticN; $i++) {
		my $tmp_x= $x1 + $i * ($tick_unit/$scale);
		my $mark=($genomic_position_start + $i * $tick_unit)/1000;
		$svg->line('x1', $tmp_x, 'y1', $y, 'x2', $tmp_x, 'y2', $y-10, 'stroke','black','stroke-width',2);
		if ($i == $ticN) {
		$svg->text('x',$tmp_x-20,'y',$y-20,'-cdata',"$mark",'font-family','Arial','font-size',1);}
		else {
		$svg->text('x',$tmp_x-20,'y',$y-20,'-cdata',"$mark (Kb)",'font-family','Arial','font-size',1);}
		#return -15; # the y space used by ruler
	}
}