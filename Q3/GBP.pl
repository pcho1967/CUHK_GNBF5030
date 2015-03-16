use warnings;
use strict;
# declare and initialize variables
my ($line, $locus, $accession, $organism, $CDS, $subseq, $seqid);
my @annotation = ( );
my $sequence = '';
my $filename = 'U49845.gb';


parse1(\@annotation, \$sequence, $filename);

open OUT, ">out.txt";

my @filter = uniq(@annotation);
print @filter;

foreach (@filter) {
	chomp $_;
	if ($_ !~ /(\d+)\t(\d+)/){
		print OUT '>'."$_\n";
	}
	if ($_ =~ /(\d+)\t(\d+)/){
	my $seqpart = substr($sequence, $1, $2);
	print_sequence($seqpart, 80, *OUT);
	}
}

#close OUT;

###########################################################################
#
#                         subroutine
#
############################################################################

sub parse1 {
my ($annotation, $dna, $filename) = @_;
my $in_sequence = 0;
my $line;
open IN, $filename;
while ($line = <IN>) {
	chomp $line;
	if ($line =~ /^\/\/\n/) { # If $line is end-ofrecord line //\n,
		last; # break out of the foreach loop.
	}
	if ($in_sequence) { # If we know we are in a sequence,
		$$dna .= $line; # add the current line to $$dna.
	} elsif ($line =~ /^ORIGIN/) { # If $line begins a sequence,
		$in_sequence = 1; # set the $in_sequence flag.
	} elsif ($line =~ /gene=\W(\w+)\W/) {
		push(@$annotation, $1."\n");
	} elsif ($line =~ /.CDS{1}\D*(\d+)\.\.(\d+)/) {
		push(@$annotation, "$1\t$2\n");
	} else {
	}
	}
close IN;
# remove whitespace and line numbers from DNA sequence
$$dna =~ s/[\s0-9]//g;
}


sub print_sequence{
my ($sequence, $length, $filehandle) = @_; 
	for (my $pos = 0; $pos < length($sequence); $pos += $length) {
		my $subseq = substr($sequence, $pos, $length);
		print $filehandle "$subseq\n";
	}
}


sub uniq {
my %seen;
grep !$seen{$_}++, @_;
}


