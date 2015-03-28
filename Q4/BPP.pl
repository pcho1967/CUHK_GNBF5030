=comment
Assemble a BLAST parser using code snippets in the slides. You need to complete the code missed. You can test your program on a BLAST ouput file
=cut

use warnings;
use strict;

my $filename = shift;
my ($beginning, $ending);
my @HSPs;

parse_blast($filename, \$beginning, \$ending, \@HSPs);


print $beginning;
for (my $i = 0; $i <= $#HSPs; ++$i) {
	print_HSP ($HSPs[$i]); # print each HSP in alignment section
}
print $ending;


sub parse_blast {
	my ($filename, $beginning_ref, $ending_ref, $alignment, $HSPs) = @_;
	# parse the blast output into 3 sections
	my ($part1, $part2, $part3); # beginning, alignments and ending
	my $in_beginning = 0;
	my $in_alignment = 0;
	my $in_ending = 0;
	open IN, $filename || die;
	while (<IN>) {
		if (/^T?BLAST[NPX]/) {$in_beginning = 1}
		if (/^ALIGNMENTS/) {$in_beginning = 0; $in_alignment = 1; next}
		if (/^\s\sDatabase/) {$in_alignment = 0; $in_ending = 1;}
		if ($in_beginning) {$part1 .= $_;}
		if ($in_alignment) {$part2 .= $_;}
		if ($in_ending) {$part3 .= $_;}
	}
	close IN;

	$$beginning_ref = $part1;
	$$ending_ref = $part3;

	#split the alignment into array
	my @alignments;
	split_alignments($part2, \@alignments);		

	#parse each alignment
	foreach my $alignment (@alignments){
		parse_one_alignment($alignment, $HSPs);

	}
}


sub split_alignments{
	my ($alignments, $aligns) = @_;
	my @alignment;
	while ($alignments =~ /^>.*\n(^(?!>).*\n)+/gm) {
		push @$aligns, $&;
	}
# magic, ^(?!>) is a negative lookahead assertion,
# a line does not start with >
}

sub parse_one_alignment{
	my $align = shift;
	my $HSPs = shift;
	my ($part1, $part2) = $align =~ /(.*?)(Score =.*)/s;

	# part 1 is subject lines
	# part 2 is HSP lines

	# correct regular expression
	while ($part2 =~ /^Score =.*\n(^(?!Score =).*\n)+/mg) {		
		my %hsp;
		parse_one_HSP ($&, \%hsp);
		push @HSPs, \%hsp;
	}
}


sub parse_one_HSP {
	my $data = shift;
	my $hsp = shift; # reference to hash
	my ($score, $expect, $identity, $querys, $querye, $subjects, $subjecte);
	# parsing one HSP ...

	($expect) = ($data =~ /Expect = (\d+.\d+)/);
	($score) = ($data =~ /Score = (\d+) bits.*/);
	($identity) = ($data =~ /Identities = (\d+)\/.*/);
	my(@query) = ($data =~ /^Query.*\n/gm);
	my(@subject) = ($data =~ /^Sbjct.*\n/gm);
	my($firstquery) = shift @query;
	($querys) = ($firstquery =~ /(\d+)/);
	my($lastquery) = pop @query;
	($querye) = ($lastquery =~ /\d+.*\D(\d+)/);	
	my($firstsubject) = shift @subject;
	($subjects) = ($firstsubject =~ /(\d+)/);
	my($lastsubject) = pop @subject;
	($subjecte) = ($lastsubject =~ /\d+.*\D(\d+)/);

	$hsp->{score} = $score;
	$hsp->{expect} = $expect;
	$hsp->{identity} = $identity;
	$hsp->{querys} = $querys;
	$hsp->{querye} = $querye;
	$hsp->{subjects} = $subjects;
	$hsp->{subjecte} = $subjecte;

}

sub print_HSP {
	my $hsp = shift;
	print "Score: $hsp->{score}\n";
	print "Expect: $hsp->{expect}\n";
	print "Identity: $hsp->{identity}\n";
	print "Query start: $hsp->{querys}\n";
	print "Query end: $hsp->{querye}\n";
	print "Subject start: $hsp->{subjects}\n";
	print "Subject end: $hsp->{subjecte}\n\n";
}

