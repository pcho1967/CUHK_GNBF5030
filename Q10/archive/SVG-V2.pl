#Complete subroutine plot gene and write a Perl program to plot the structure of human genes using SVG.

use strict;
use warnings;
use GeneIO; #for read refgene file
use UCSCGene; # a gene class refer UCSC model
use SVG;

my $obj = GeneIO->new(  );
my $gene = UCSCGene->new();
my $in_file = "refGene.txt";
my %genelist;
my @newdataset;
my $j = 0;
my $genes;
my %row_end;


$obj->read(#read in refgene.txt file
  filename => $in_file
);

my @newdata = $obj->get_filedata; #get file data 
$obj->set_filedata( \@newdata );

foreach (@newdata) {# extract part of UCSC record into individual UCSCGene object
my $i = shift @newdata;
$j = $j + 1;
my @data = split /[\t\n]+/;
	if ($data[3] eq '+' && $ data[2] eq "chr11" && $data[4] > 1960000 && $data[5] < 2150000){ #select part of genome fall within ruler range as pilot study
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
}

my $svg = SVG->new('width', 1280,'height', 768);
# the start of the genomic position on the plot
my $genomic_position_start = 1960000;
# the end of the genomic position on the plot
my $genomic_position_end = 2150000;
my $left_margin_width = 50;
my $scale = 200; # 200b per pixel
my $tick_unit= 10000; # 10kb a tick
my $y = 50; # the y coordiates to start the plot of genes
my $tmp_y;
my @genes;


# main for plot graph
for my $key (keys %genelist){ #get gene information from list of UCSCgene object
	my $genes =  $genelist{$key}; # get a hash or a gene object
	my $height = plot_genes($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $genes, $y);
	next;
}
plot_ruler($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $y, $tick_unit);

#export and save image 
open OUT,">out.svg";
print OUT $svg->xmlify();
close OUT;
# end of main 


#################################################################################################################
#                                                                                                               #                           
#                                                 Subroutine                                                    #
#                                                                                                               #
#################################################################################################################
    
sub plot_genes {
#collect parameters
my $svg =shift;
my $genomic_position_start = shift;
my $genomic_position_end = shift;
my $scale = shift;
my $left_margin_width = shift;
my $genes = shift;
my $y = shift;

# sort genes by the start position ...

# plot each gene, if a gene overlap with the previous one, plot it on a new row
my $row = 0;
my $row_skip = 50; # number of pixels per row
 # keep the end position of the previous gene in each row

#foreach my $g (@$genes) {

# determine which row to plot
my $k = -1;
my $g = $genes;

for (my $i =0; $i <= $row; $i++) {
	if (not defined $row_end{$i}) { # no gene at row i
		$k = $i;
		} elsif ($g->get_txStart > $row_end{$i}) {
		$k = $i;
		} else {# nothing to do here, goto the next row}
	}
	if ($k == -1) {$row++; $k = $row;}
	# plot gene
	my $tmp_y = $y + $k * $row_skip;
	print $g->get_chrom."\t".$g->get_genename."\t".$g -> get_txStart. "\t".$g -> get_txEnd ."\n";
	plot_gene($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $g, $tmp_y);
	
	# update the end postion of the k-th row
	$row_end{$k} = $g->get_txEnd;
	}
	return $row_skip * ($row + 1); # the total height of gene track
}
#}

sub plot_gene {
	my $svg = shift;
	my $genomic_position_start = shift;
	my $genomic_position_end = shift;
	my $scale = shift;
	my $left_margin_width = shift;
	my $g = shift;
	my $tmp_y = shift;
	my $x1 = $left_margin_width + int(($g -> get_txStart - $genomic_position_start)/$scale); my $x2 = int(($g->get_txEnd - $g->get_txStart)/$scale) ; 
	#Ok  $svg->rect('x',$x1,'y',$tmp_y,'width',$x2,'height',20,'fill','green','stroke','green','stroke-width',1);
	$svg->text('x',$x1-20,'y',$tmp_y - 1,'-cdata', $g->get_genename,'font-family','Arial','font-size',1);
	plot_chrom($left_margin_width, $g, $tmp_y);
	#plot_utr ($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $g, $tmp_y);
	plot_exon ($left_margin_width, $g, $tmp_y,$scale);
	plot_intron ($left_margin_width, $g, $tmp_y,$scale);
	#plot_utr ($svg, $genomic_position_start, $genomic_position_end, $scale, $left_margin_width, $g, $tmp_y);
}

sub plot_chrom{
	my $x1 = shift;
	my $g = shift;
	my $tmp_y = shift;	
		$svg->text('x',$x1 - 40,'y',$tmp_y+15,'-cdata', $g->get_chrom,'font-family','Arial','font-size',1);
}

sub plot_exon{
	my $left_margin_width = shift;
	my $g = shift;
	my $tmp_y = shift;
	my $scale = shift;	
	my @exon_beg = split /,/, $g->get_exonStarts;
 	my @exon_end = split /,/, $g->get_exonEnds;
# use for loop to write all exon start and end location 
 		for(my $i = 0; $i < $g->get_exonCount; ++$i){
 		my $x1= int(($exon_beg[$i]- $genomic_position_start)/$scale) + $left_margin_width;
		my $x2= int(($exon_end[$i] - $exon_beg[$i])/$scale);
		$svg->rect('x',$x1,'y',$tmp_y,'width',$x2,'height',20,'fill','green','stroke','green','stroke-width',1);
		next;
		}
}

sub plot_intron {
	my $left_margin_width = shift;
	my $g = shift;
	my $tmp_y = shift;
	my $scale = shift;	
	my @exon_beg = split /,/, $g->get_exonStarts;
 	my @exon_end = split /,/, $g->get_exonEnds;
# use for loop to write all exon start and end location 
 		for(my $i = 0; $i < ($g->get_exonCount -1); ++$i){
 		my $x1= int(($exon_end[$i] - $genomic_position_start)/$scale) + $left_margin_width;
		my $x2= int(($exon_beg[$i+1]- $genomic_position_start)/$scale) + $left_margin_width;;
		print $x2."\n";
		$svg->line('x1',$x1,'y1',$tmp_y+10,'x2',$x2,'y2',$tmp_y+10,'stroke','green','stroke-width',1);
		for (my $a = 0; $a <= int(($x2-$x1)/8);$a++){
			$svg->line('x1',$x1+$a*8,'y1',$tmp_y+10,'x2',$x1+$a*8,'y2',$tmp_y + 14,'stroke','green','stroke-width',1);
			$svg->line('x1',$x1+$a*8,'y1',$tmp_y+10,'x2',$x1+$a*8,'y2',$tmp_y + 6,'stroke','green','stroke-width',1);}	
		}
}

sub plot_utr{
	my $x1 = int($genomic_position_start/$scale); my $x2 = int($genomic_position_end/$scale) ; 
		$svg->rect('x',$x1,'y',$tmp_y,'width',$x2-$x1,'height',20,'fill','white','fill-opacity',0.8,'stroke',"green",'stroke-width',1);
}

sub plot_ruler {
	my $svg = shift;
	my $genomic_position_start = shift;
	my $genomic_position_end = shift;
	my $scale = shift;
	my $left_margin_width = shift;
	my $y = shift;
	my $tick_unit = shift;
	my $length = $genomic_position_end - $genomic_position_start;
	my $ticN = 0;
	if ($length % $tick_unit == 0) {$ticN = $length/$tick_unit;} 
	else {$ticN = ($length/$tick_unit)+1;}
	my $x1 = $left_margin_width; my $x2 = ($left_margin_width) + int($length/$scale) ; 
		$svg->line('x1',$x1,'y1',$y-10,'x2',$x2,'y2',$y-10,'stroke','black','stroke-width',1);
	for (my $i=0; $i <= $ticN; $i++) {
		my $tmp_x= int($x1 + $i * ($tick_unit/$scale));
		my $mark = int($genomic_position_start + $i * $tick_unit)/1000;
		$svg->line('x1', $tmp_x, 'y1', $y-10, 'x2', $tmp_x, 'y2', $y-20, 'stroke','black','stroke-width',1);
		if ($i == $ticN) {
		$svg->text('x',$tmp_x-20,'y',$y-30,'-cdata',"$mark (Kb)",'font-family','Arial','font-size',1);}
		else {
		$svg->text('x',$tmp_x-20,'y',$y-30,'-cdata',"$mark",'font-family','Arial','font-size',1);}
		}
		return 15; # the y space used by ruler
	}
