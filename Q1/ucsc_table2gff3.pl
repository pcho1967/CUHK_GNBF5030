#!/usr/bin/perl

# documentation at end of file

use strict;
use Getopt::Long;
use Pod::Usage;
use Net::FTP;
use Bio::SeqFeature::Lite;
use Bio::ToolBox::file_helper qw(
	open_to_read_fh
	open_to_write_fh
);
use Bio::ToolBox::utility;
my $VERSION = '1.20';

print "\n A script to convert UCSC tables to GFF3 files\n\n";




### Quick help
unless (@ARGV) { 
	# when no command line options are present
	# print SYNOPSIS
	pod2usage( {
		'-verbose' => 0, 
		'-exitval' => 1,
	} );
}



### Command line options
my (
	$ftp_file,
	$database,
	$host,
	$do_chromo,
	$refseqstatusf,
	$refseqsumf,
	$ensemblnamef,
	$ensemblsourcef,
	$kgxreff,
	$chromof,
	$user_source,
	$do_gene,
	$do_cds,
	$do_utr,
	$do_codon,
	$recycle,
	$do_name,
	$gz,
	$help,
	$print_version,
);
my @genetables;
GetOptions( 
	'ftp=s'      => \$ftp_file, # which database table to retrieve
	'db=s'       => \$database, # which ucsc genome to use
	'host=s'     => \$host, # the ftp server to connect to
	'chr!'       => \$do_chromo, # include the chromosome file from ftp
	'table=s'    => \@genetables, # the input gene table files
	'status=s'   => \$refseqstatusf, # the refseqstatus file
	'sum=s'      => \$refseqsumf, # the refseqsummary file
	'kgxref=s'   => \$kgxreff, # the kgXref info file
	'ensname=s'  => \$ensemblnamef, # the ensemblToGeneName file
	'enssrc=s'   => \$ensemblsourcef, # the ensemblSource file
	'chromo=s'   => \$chromof, # a chromosome file
	'source=s'   => \$user_source, # user provided source
	'gene!'      => \$do_gene, # include genes in output
	'cds!'       => \$do_cds, # include CDS in output
	'utr!'       => \$do_utr, # include UTRs in output
	'codon!'     => \$do_codon, # include start & stop codons in output
	'share!'     => \$recycle, # recycle common exons and UTRs
	'name!'      => \$do_name, # assign names to CDSs, UTRs, and exons
	'gz!'        => \$gz, # compress file
	'help'       => \$help, # request help
	'version'    => \$print_version, # print the version
) or die " unrecognized option(s)!! please refer to the help documentation\n\n";

# Print help
if ($help) {
	# print entire POD
	pod2usage( {
		'-verbose' => 2,
		'-exitval' => 1,
	} );
}

# Print version
if ($print_version) {
	print " Biotoolbox script ucsc_table2gff3.pl, version $VERSION\n\n";
	exit;
}





### Check requirements and defaults
unless (@genetables or $ftp_file or $chromof) {
	die " Specify either an input table file, chromosome file, or a FTP table!\n";
}
if ($ftp_file) {
	unless ($ftp_file =~ m/^refgene|ensgene|xenorefgene|known|all$/i) {
		die " requested table '$ftp_file' by FTP not supported! see help\n";
	}
	unless (defined $database) {
		die " a UCSC genome database must be provided! see help\n";
	}
	unless (defined $do_chromo) {
		$do_chromo = 1;
	}
	unless (defined $host) {
		$host = 'hgdownload.cse.ucsc.edu';
	}
}
unless (defined $do_gene) {
	$do_gene = 1;
}
unless (defined $do_utr) {
	$do_utr = 0;
}
unless (defined $do_cds) {
	$do_cds = 1;
	unless (defined $do_codon) {
		$do_codon = 0;
	}
}
unless (defined $recycle) {
	$recycle = 1;
}
unless (defined $do_name) {
	$do_name = 0;
}
my $start_time = time;




### Fetch files if requested
if ($ftp_file) {
	
	# collect the requested files by ftp
	my @files = fetch_files_by_ftp();
	
	# push file names into appropriate variables
	foreach my $file (@files) {
		if ($file =~ /refgene|ensgene|knowngene/i) {
			push @genetables, $file;
		}
		elsif ($file =~ /summary/i) {
			$refseqsumf = $file;
		}
		elsif ($file =~ /status/i) {
			$refseqstatusf = $file;
		}
		elsif ($file =~ /ensembltogene/i) {
			$ensemblnamef = $file;
		}
		elsif ($file =~ /ensemblsource/i) {
			$ensemblsourcef = $file;
		}
		elsif ($file =~ /kgxref/i) {
			$kgxreff = $file;
		}
		elsif ($file =~ /chrom/i) {
			$chromof = $file;
		}
	}
}




### Process the gene tables

# input accessory files
	# the load_extra_data() will read the appropriate file, if available,
	# and return the hash of the data
	# it is generic for handling multiple data types
	# pass the type of table we're working with
my $refseqsum   = load_extra_data('summary');

my $refseqstat  = load_extra_data('status');

my $kgxref      = load_extra_data('kgxref');

my $ensembldata = load_extra_ensembl_data();


# initialize globals
my $chromosome_done = 0; # boolean indicating chromosomes are written
my $source; # a re-usable global, may change depending on input table

# walk through the input tables
foreach my $file (@genetables) {
	
	# open output file
	my ($outfile, $gff_fh) = open_output_gff($file);
	
	# process chromosome
	if ($chromof and !$chromosome_done) {
		# if there is only one genetable, we will prepend the chromosomes 
		# to that output file, otherwise we'll make a separate gff file
		# I'm making this assumption because the chromosomes only need to be 
		# defined once when loading Bio::DB::SeqFeature::Store database
		# If user is collecting multiple gene tables, then separate files 
		# are ok, probably preferable, than a gigantic one
		print " Writing chromosome features....\n";
		
		if (scalar @genetables > 1) {
			# let's write a separate chromosome gff file
			
			# open new filehandle
			my ($chromo_outfile, $chromo_gff_fh) = open_output_gff($chromof);
			
			# convert the chromosomes
			print_chromosomes($chromo_gff_fh);
			
			# done
			$chromo_gff_fh->close;
			print " Wrote chromosome GFF file '$chromo_outfile'\n"; 
			$chromosome_done = 1;
		}
		else {
			# let's write to one gff file
			print_chromosomes($gff_fh);
			$chromosome_done = 1;
		}
	}	
	
	# set the source 
	if (defined $user_source) {
		$source = $user_source;
	}
	else {
		# determine from the input filename
		if ($file =~ /xenorefgene/i) {
			$source = 'xenoRefGene';
		}
		elsif ($file =~ /refgene/i) {
			$source = 'refGene';
		}
		elsif ($file =~ /ensgene/i) {
			$source = 'ensGene';
		}
		elsif ($file =~ /knowngene/i) {
			$source = 'knownGene';
		}
		else {
			$source = 'UCSC';
		}
	}
	
	# open the input gene table
	my $table_fh = open_to_read_fh($file) or
		die " unable to open gene table file '$file'!\n";
	
	# convert the table depending on what it is
	print " Converting gene table '$file' features....\n";
	my $count = process_gene_table($table_fh, $gff_fh);
	
	# report outcomes
	print "  converted ", format_with_commas($count->{gene}), 
		" gene features\n" if $count->{gene} > 0;
	print "  converted ", format_with_commas($count->{mrna}), 
		" mRNA transcripts\n" if $count->{mrna} > 0;
	print "  converted ", format_with_commas($count->{pseudogene}), 
		" pseudogene transcripts\n" if $count->{pseudogene} > 0;
	print "  converted ", format_with_commas($count->{ncrna}), 
		" ncRNA transcripts\n" if $count->{ncrna} > 0;
	print "  converted ", format_with_commas($count->{mirna}), 
		" miRNA transcripts\n" if $count->{mirna} > 0;
	print "  converted ", format_with_commas($count->{snrna}), 
		" snRNA transcripts\n" if $count->{snrna} > 0;
	print "  converted ", format_with_commas($count->{snorna}), 
		" snoRNA transcripts\n" if $count->{snorna} > 0;
	print "  converted ", format_with_commas($count->{trna}), 
		" tRNA transcripts\n" if $count->{trna} > 0;
	print "  converted ", format_with_commas($count->{rrna}), 
		" rRNA transcripts\n" if $count->{rrna} > 0;
	print "  converted ", format_with_commas($count->{other}), 
		" other transcripts\n" if $count->{other} > 0;
	
	# Finished
	printf "  wrote file '$outfile' in %.1f minutes\n", 
		(time - $start_time)/60;
	
}



### Finish
exit;





#########################  Subroutines  #######################################

sub fetch_files_by_ftp {
	
	
	# generate ftp request list
	my @ftp_files;
	if ($ftp_file eq 'all') {
		@ftp_files = qw(
			refgene
			ensgene
			xenorefgene
			known
		);
	}
	elsif ($ftp_file =~ /,/) {
		@ftp_files = split /,/, $ftp_file;
	}
	else {
		push @ftp_files, $ftp_file;
	}
	
	# generate list of files
	my @files;
	foreach my $item (@ftp_files) {
		if ($item =~ m/^xeno/i) {
			push @files, qw(
				xenoRefGene.txt.gz 
				refSeqStatus.txt.gz 
				refSeqSummary.txt.gz
			);
		}
		elsif ($item =~ m/refgene/i) {
			push @files, qw(
				refGene.txt.gz 
				refSeqStatus.txt.gz 
				refSeqSummary.txt.gz
			);
		}
		elsif ($item =~ m/ensgene/i) {
			push @files, qw(
				ensGene.txt.gz 
				ensemblToGeneName.txt.gz
				ensemblSource.txt.gz
			);
		}
		elsif ($item =~ m/known/i) {
			push @files, qw(
				knownGene.txt.gz 
				kgXref.txt.gz 
			);
		}
	}
	# this might seem convulated....
	# but we're putting all the file names in a single array
	# instead of specific global variables
	# to make retrieving through FTP a little easier
	# plus, not all files may be available for each species, e.g. knownGene
	# we also rename the files after downloading them
	
	# we will sort out the list of downloaded files later and assign them 
	# to specific global filename variables
	
	# add chromosome file if requested
	if ($do_chromo) {
		push @files, 'chromInfo.txt.gz';
	}
	
	# set the path based on user provided database
	my $path = 'goldenPath/' . $database . '/database/';
	
	# initiate connection
	print " Connecting to $host....\n";
	my $ftp = Net::FTP->new($host) or die "Cannot connect! $@";
	$ftp->login or die "Cannot login! " . $ftp->message;
	
	# prepare for download
	$ftp->cwd($path) or 
		die "Cannot change working directory to '$path'! " . $ftp->message;
	$ftp->binary;
	
	# download requested files
	my @fetched_files;
	foreach my $file (@files) {
		print "  fetching $file....\n";
		# prepend the local file name with the database
		my $new_file = $database . '_' . $file;
		
		# fetch
		if ($ftp->get($file, $new_file) ) { 
			push @fetched_files, $new_file;
		}
		else {	
			my $message = $ftp->message;
			if ($message =~ /no such file/i) {
				print "   file unavailable\n";
			}
			else {
				warn $message;
			}
		}
	}
	$ftp->quit;
	
	print " Finished\n";
	return @fetched_files;
}




sub load_extra_data {
	# this will load extra tables of information into hash tables
	# this includes tables of descriptive information, such as 
	# status, summaries, common gene names, etc.
	
	# this sub is designed to be generic to be reusable for multiple 
	# data files
	
	# identify the appropriate file to use based on the type of 
	# table information being loaded
	# the file name should've been provided by command line or ftp
	my $type = shift;
	my %data;
	my $file;
	if ($type eq 'summary') {
		$file = $refseqsumf;
	}
	elsif ($type eq 'status') {
		$file = $refseqstatusf;
	}
	elsif ($type eq 'kgxref') {
		$file = $kgxreff;
	}
	
	# the appropriate data table file wasn't provided for the requested 
	# data table, return an empty hash
	return \%data unless defined $file;
	
	# load file
	my $fh = open_to_read_fh($file) or 
		die " unable to open $type file '$file'!\n";
	
	# load into hash
	while (my $line = $fh->getline) {
		
		# process line
		chomp $line;
		next if ($line =~ /^#/);
		my @line_data = split /\t/, $line;
		
		# the unique id should be the first element in the array
		# take it off the array, since it doesn't need to be stored there too
		my $id = shift @line_data;
		
		# check for duplicate lines
		if (exists $data{$id} ) {
			warn "  $type line for identifier $id exists twice!\n";
			next;
		}
		
		# store data into hash
		$data{$id} = [@line_data];
	}
	
	# finish
	print " Loaded ", format_with_commas( scalar(keys %data) ), 
		" transcripts from $type file '$file'\n";
	$fh->close;
	return \%data;

	### refSeqStatus table
	# 0	mrnaAcc	RefSeq gene accession name
	# 1	status	Status ('Unknown', 'Reviewed', 'Validated', 'Provisional', 'Predicted', 'Inferred')
	# 2	molecule type ('DNA', 'RNA', 'ds-RNA', 'ds-mRNA', 'ds-rRNA', 'mRNA', 'ms-DNA', 'ms-RNA', 'rRNA', 'scRNA', 'snRNA', 'snoRNA', 'ss-DNA', 'ss-RNA', 'ss-snoRNA', 'tRNA', 'cRNA', 'ss-cRNA', 'ds-cRNA', 'ms-rRNA')	values	molecule type
	
	### refSeqSummary table
	# 0	RefSeq mRNA accession
	# 1	completeness	FullLength ('Unknown', 'Complete5End', 'Complete3End', 'FullLength', 'IncompleteBothEnds', 'Incomplete5End', 'Incomplete3End', 'Partial')	
	# 1	summary	 	text	values	Summary comments
	
	### kgXref table
	# 0	kgID	Known Gene ID
	# 1	mRNA	mRNA ID
	# 2	spID	SWISS-PROT protein Accession number
	# 3	spDisplayID	 SWISS-PROT display ID
	# 4	geneSymbol	Gene Symbol
	# 5	refseq	 RefSeq ID
	# 6	protAcc	 NCBI protein Accession number
	# 7	description	Description
	
	### ensemblToGeneName table
	# 0 Ensembl transcript ID
	# 1 gene name
}


sub load_extra_ensembl_data {
	# we will combine the ensemblToGeneName and ensemblSource data tables
	# into a single hash keyed by the ensGene transcript ID
	# Both tables are very simple two columns, so just trying to conserve
	# memory by combining them
	
	# initialize
	my %data;
		# key will be the ensembl transcript id
		# value will be anonymous array of [name, source]
	
	# load ensemblToGeneName first
	if ($ensemblnamef) {
		
		# open file
		my $fh = open_to_read_fh($ensemblnamef) or 
			die " unable to open file '$ensemblsourcef'!\n";
		
		# load into hash
		my $count = 0;
		while (my $line = $fh->getline) {
			
			# process line
			chomp $line;
			next if ($line =~ /^#/);
			my @line_data = split /\t/, $line;
			if (scalar @line_data != 2) {
				die " file $ensemblnamef doesn't seem right!? Line has " .
					scalar @line_data . " elements!\n";
			}
			
			# store data into hash
			$data{ $line_data[0] }->[0] = $line_data[1];
			$count++;
		}
		
		# finish
		print " Loaded ", format_with_commas($count), 
			" names from file '$ensemblnamef'\n";
		$fh->close;
	}
	
	# load ensemblSource second
	if ($ensemblsourcef) {
	
		# open file
		my $fh = open_to_read_fh($ensemblsourcef) or 
			die " unable to open file '$ensemblsourcef'!\n";
		
		# load into hash
		my $count = 0;
		while (my $line = $fh->getline) {
			
			# process line
			chomp $line;
			next if ($line =~ /^#/);
			my @line_data = split /\t/, $line;
			if (scalar @line_data != 2) {
				die " file $ensemblsourcef doesn't seem right!? Line has " .
					scalar @line_data . " elements!\n";
			}
			
			# store data into hash
			$data{ $line_data[0] }->[1] = $line_data[1];
			$count++;
		}
		
		# finish
		print " Loaded ", format_with_commas($count), 
			" transcript types from file '$ensemblsourcef'\n";
		$fh->close;
	}
	
	# done, return reference if we loaded data
	return %data ? \%data : undef; 
}



sub open_output_gff {
	
	# prepare output file name
	my $file = shift;
	my $outfile = $file;
	$outfile =~ s/\.txt(?:\.gz)?$//i; # remove the extension
	$outfile .= '.gff3';
	if ($gz) {
		$outfile .= '.gz';
	}
	
	# open file handle
	my $fh = open_to_write_fh($outfile, $gz) or
		die " unable to open file '$outfile' for writing!\n";
	
	# print comments
	$fh->print( "##gff-version 3\n");
	$fh->print( "##genome-build UCSC $database\n") if $database;
	$fh->print( "# UCSC table file $file\n");
	
	# finish
	return ($outfile, $fh);
}


sub process_line_data {
	
	my $line = shift;
	my %data;
	
	# load the relevant data from the table line into the hash
	# using the identified column indices
	chomp $line;
	my @linedata = split /\t/, $line;
	
	# we're identifying the type of table based on the number of columns
	# maybe not the best or accurate, but it works for now
	
	# don't forget to convert start from 0 to 1-based coordinates
	
	if (scalar @linedata == 16) {
		# an extended gene prediction table, e.g. refGene, ensGene, xenoRefGene
		# as downloaded from the UCSC Table Browser or FTP site
		
		# 0  bin
		# 1  name
		# 2  chrom
		# 3  strand
		# 4  txStart
		# 5  txEnd
		# 6  cdsStart
		# 7  cdsEnd
		# 8  exonCount
		# 9  exonStarts
		# 10 exonEnds
		# 11 score
		# 12 name2
		# 13 cdsStartStat
		# 14 cdsEndStat
		# 15 exonFrames
		
		$data{name}        = $linedata[1];
		$data{chrom}       = $linedata[2];
		$data{strand}      = $linedata[3];
		$data{txStart}     = $linedata[4] + 1;
		$data{txEnd}       = $linedata[5];
		$data{cdsStart}    = $linedata[6] + 1;
		$data{cdsEnd}      = $linedata[7];
		$data{exonCount}   = $linedata[8];
		$data{exonStarts}  = $linedata[9];
		$data{exonEnds}    = $linedata[10];
		$data{name2}       = $linedata[12] || undef;
		$data{note}        = $refseqsum->{ $linedata[1] }->[1] || undef;
		$data{status}      = $refseqstat->{ $linedata[1] }->[0] || undef;
		$data{completeness} = $refseqsum->{ $linedata[1] }->[0] || undef;
		if ($linedata[1] =~ /^N[MR]_\d+/) {
			$data{refseq} = $linedata[1];
		}
	}
	elsif (scalar @linedata == 15) {
		# an extended gene prediction table, e.g. refGene, ensGene, xenoRefGene
		# without the bin value
		
		# 0  name
		# 1  chrom
		# 2  strand
		# 3  txStart
		# 4  txEnd
		# 5  cdsStart
		# 6  cdsEnd
		# 7  exonCount
		# 8  exonStarts
		# 9 exonEnds
		# 10 score
		# 11 name2
		# 12 cdsStartStat
		# 13 cdsEndStat
		# 14 exonFrames
		
		$data{name}        = $linedata[0];
		$data{chrom}       = $linedata[1];
		$data{strand}      = $linedata[2];
		$data{txStart}     = $linedata[3] + 1;
		$data{txEnd}       = $linedata[4];
		$data{cdsStart}    = $linedata[5] + 1;
		$data{cdsEnd}      = $linedata[6];
		$data{exonCount}   = $linedata[7];
		$data{exonStarts}  = $linedata[8];
		$data{exonEnds}    = $linedata[9];
		$data{name2}       = $linedata[11] || undef;
		$data{note}        = $refseqsum->{ $linedata[0] }->[1] || undef;
		$data{status}      = $refseqstat->{ $linedata[0] }->[0] || undef;
		$data{completeness} = $refseqsum->{ $linedata[0] }->[0] || undef;
		if ($linedata[0] =~ /^N[MR]_\d+/) {
			$data{refseq} = $linedata[0];
		}
	}
	elsif (scalar @linedata == 12) {
		# a knownGene table
		
		# 0 name	known gene identifier
		# 1 chrom	Reference sequence chromosome or scaffold
		# 2 strand	+ or - for strand
		# 3 txStart	Transcription start position
		# 4 txEnd	Transcription end position
		# 5 cdsStart	Coding region start
		# 6 cdsEnd	Coding region end
		# 7 exonCount	Number of exons
		# 8 exonStarts	Exon start positions
		# 9 exonEnds	Exon end positions
		# 10 proteinID	UniProt display ID for Known Genes, UniProt accession or RefSeq protein ID for UCSC Genes
		# 11 alignID	Unique identifier for each (known gene, alignment position) pair
		
		$data{name}       = $kgxref->{ $linedata[0] }->[0] ||
							$linedata[0];
		$data{chrom}      = $linedata[1];
		$data{strand}     = $linedata[2];
		$data{txStart}    = $linedata[3] + 1;
		$data{txEnd}      = $linedata[4];
		$data{cdsStart}   = $linedata[5] + 1;
		$data{cdsEnd}     = $linedata[6];
		$data{exonCount}  = $linedata[7];
		$data{exonStarts} = $linedata[8];
		$data{exonEnds}    = $linedata[9];
		$data{name2}       = $kgxref->{ $linedata[0] }->[3] || # geneSymbol
							 $kgxref->{ $linedata[0] }->[0] || # mRNA id
							 $kgxref->{ $linedata[0] }->[4] || # refSeq id
							 $linedata[0]; # ugly default
		$data{note}        = $kgxref->{ $linedata[0] }->[6] || undef;
		$data{refseq}      = $kgxref->{ $linedata[0] }->[4] || undef;
		$data{status}      = $refseqstat->{ $data{refseq} }->[0] || undef;
		$data{completeness} = $refseqsum->{ $data{refseq} }->[0] || undef;
		$data{spid}        = $kgxref->{ $linedata[0] }->[1] || undef; # SwissProt ID
		$data{spdid}       = $kgxref->{ $linedata[0] }->[2] || undef; # SwissProt display ID
		$data{protacc}     = $kgxref->{ $linedata[0] }->[5] || undef; # NCBI protein accession
	}
	elsif (scalar @linedata == 11) {
		# a refFlat gene prediction table
		
		# 0  name2 or gene name
		# 1  name or transcript name
		# 2  chrom
		# 3  strand
		# 4  txStart
		# 5  txEnd
		# 6  cdsStart
		# 7  cdsEnd
		# 8  exonCount
		# 9  exonStarts
		# 10 exonEnds
		
		$data{name2}       = $linedata[0];
		$data{name}        = $linedata[1];
		$data{chrom}       = $linedata[2];
		$data{strand}      = $linedata[3];
		$data{txStart}     = $linedata[4] + 1;
		$data{txEnd}       = $linedata[5];
		$data{cdsStart}    = $linedata[6] + 1;
		$data{cdsEnd}      = $linedata[7];
		$data{exonCount}   = $linedata[8];
		$data{exonStarts}  = $linedata[9];
		$data{exonEnds}    = $linedata[10];
		$data{note}        = $refseqsum->{ $linedata[1] }->[1] || undef;
		$data{status}      = $refseqstat->{ $linedata[1] }->[0] || undef;
		$data{completeness} = $refseqsum->{ $linedata[1] }->[0] || undef;
		if ($linedata[1] =~ /^N[MR]_\d+/) {
			$data{refseq} = $linedata[1];
		}
	}
	elsif (scalar @linedata == 10) {
		# a simple gene prediction table, e.g. refGene, ensGene, xenoRefGene
		
		# 0  name
		# 1  chrom
		# 2  strand
		# 3  txStart
		# 4  txEnd
		# 5  cdsStart
		# 6  cdsEnd
		# 7  exonCount
		# 8  exonStarts
		# 9  exonEnds
		
		$data{name}        = $linedata[0];
		$data{chrom}       = $linedata[1];
		$data{strand}      = $linedata[2];
		$data{txStart}     = $linedata[3] + 1;
		$data{txEnd}       = $linedata[4];
		$data{cdsStart}    = $linedata[5] + 1;
		$data{cdsEnd}      = $linedata[6];
		$data{exonCount}   = $linedata[7];
		$data{exonStarts}  = $linedata[8];
		$data{exonEnds}    = $linedata[9];
		$data{name2}       = $linedata[0]; # re-use transcript name
		$data{note}        = $refseqsum->{ $linedata[0] }->[1] || undef;
		$data{status}      = $refseqstat->{ $linedata[0] }->[0] || undef;
		$data{completeness} = $refseqsum->{ $linedata[0] }->[0] || undef;
		if ($linedata[0] =~ /^N[MR]_\d+/) {
			$data{refseq} = $linedata[0];
		}
	}
	else {
		# unrecognized line format
		return scalar @linedata;
	}
	
	# verify
# 	return unless $data{name}       =~ /^[\w\-]+$/;
# 	return unless $data{strand}     =~ /^[\+\-]$/;
# 	return unless $data{txStart}    =~ /^\d+$/;
# 	return unless $data{txEnd}      =~ /^\d+$/;
# 	return unless $data{cdsStart}   =~ /^\d+$/;
# 	return unless $data{cdsEnd}     =~ /^\d+$/;
# 	return unless $data{exonStarts} =~ /^[\d,]+$/;
# 	return unless $data{exonEnds}   =~ /^[\d,]+$/;
	
	# fix values
	$data{strand} = $data{strand} eq '+' ? 1 : -1;
	$data{exonStarts}  = [ map {$_ += 1} ( split ",", $data{exonStarts} ) ];
	$data{exonEnds}    = [ ( split ",", $data{exonEnds} ) ];
	
	return \%data;
}




sub process_gene_table {
	
	my ($table_fh, $gff_fh) = @_;
	
	# initialize 
	my %gene2seqf; # hash to assemble genes and/or transcripts for this chromosome
	my %id2count; # hash to aid in generating unique primary IDs
	my %counts = (
		'gene'       => 0,
		'mrna'       => 0,
		'pseudogene' => 0,
		'ncrna'      => 0,
		'mirna'      => 0,
		'snrna'      => 0,
		'snorna'     => 0,
		'trna'       => 0,
		'rrna'       => 0,
		'other'      => 0,
	);
	
	
	#### Main Loop
	while (my $line = $table_fh->getline) {
		
		## process the row from the gene table
		next if $line =~ /^#/;
		my $linedata = process_line_data($line);
		unless (ref $linedata eq 'HASH') {
			warn " The following line is unrecognized as a valid table line! Has $linedata elements Skipping line\n";
			warn $line;
			next;
		}
		
		## find or generate gene as necessary
		my $gene = find_gene($linedata, \%gene2seqf, \%id2count, \%counts);
		
		
		## generate the transcript
		my $transcript = generate_new_transcript($linedata, \%id2count, $gene);
		
			
		## count the transcript type
		my $type = $transcript->primary_tag;
		if ($type eq 'mRNA') {
			$counts{mrna}++;
		}
		elsif ($type eq 'pseudogene') {
			$counts{pseudogene}++;
		}
		elsif ($type eq 'ncRNA') {
			$counts{ncrna}++;
		}
		elsif ($type eq 'miRNA') {
			$counts{mirna}++;
		}
		elsif ($type eq 'snRNA') {
			$counts{snrna}++;
		}
		elsif ($type eq 'snoRNA') {
			$counts{snorna}++;
		}
		elsif ($type eq 'tRNA') {
			$counts{trna}++;
		}
		elsif ($type eq 'rRNA') {
			$counts{rrna}++;
		}
		else {
			$counts{other}++;
		}
		
		
		## associate transcript with gene
		if ($do_gene) {
			# associate our transcript with the gene
			$gene->add_SeqFeature($transcript);
		}
		else {
			# do not assemble transcripts into genes
			# we will still use the gene2seqf hash, just organized by 
			# transcript name
			# there may be more than one transcript with the same name
			
			if (exists $gene2seqf{ lc $linedata->{name} }) {
				push @{ $gene2seqf{ lc $linedata->{name} } }, $transcript;
			}
			else {
				$gene2seqf{ lc $linedata->{name} } = [ $transcript ];
			}
		}
		
	} # Finished working through the table
	
	
	
	#### Finished
	
	# print remaining current genes and transcripts
	print_current_gene_list(\%gene2seqf, $gff_fh);
	
	# return the counts
	return \%counts;
}



sub find_gene {
	my ($linedata, $gene2seqf, $id2count, $counts) = @_;
	
	# go no further unless genes are requested
	return unless $do_gene;
	
	# we want to assemble transcripts into genes
	# multiple transcripts may be associated with a single gene
	# genes are store in the gene2seqf hash
	# there may be more than one gene with identical gene name, but with 
	# non-overlapping transcripts! (how complicated!)
	my $gene;
	
	## check if gene exists
	if (exists $gene2seqf->{ lc $linedata->{name2} }) {
		# we already have a gene for this transcript
		
		# pull out the gene seqfeature(s)
		my $genes = $gene2seqf->{ lc $linedata->{name2} };
		
		# check that the current transcript intersects with the gene
		# sometimes we can have two separate transcripts with the 
		# same gene name, but located on opposite ends of the chromosome
		# part of a gene family, but unlikely the same gene 200 Mb in 
		# length
		foreach my $g (@$genes) {
			if ( 
				# overlap method borrowed from Bio::RangeI
				($g->strand == $linedata->{strand}) and not (
					$g->start > $linedata->{txEnd} or 
					$g->end < $linedata->{txStart}
				)
			) {
				# gene and transcript overlap on the same strand
				# we found the intersecting gene
				$gene = $g;
				last;
			}
		}
		
		# we have a gene for our transcript
		if ($gene) {
			# update the gene coordinates if necessary
			if ( ($linedata->{txStart}) < $gene->start) {
				# update the transcription start position
				$gene->start( $linedata->{txStart} );
			}
			if ($linedata->{txEnd} > $gene->end) {
				# update the transcription stop position
				$gene->end( $linedata->{txEnd} );
			}
			
			# update extra attributes as necessary
			update_attributes($gene, $linedata);
		}
		
		# NONE of the genes and our transcript overlap
		else {
			# must make a new gene
			$gene = generate_new_gene($linedata, $id2count);
			$counts->{gene}++;
			
			# store the new gene oject into the gene hash
			push @{ $genes }, $gene;
		}
	}
	
	## no gene exists
	else {
		# generate new gene SeqFeature object
		$gene = generate_new_gene($linedata, $id2count);
		$counts->{gene}++;
		
		# store the gene oject into the gene hash
		$gene2seqf->{ lc $linedata->{name2} } = [ $gene ];
	} 
	
	
	# Update gene note if necessary
	unless ($gene->has_tag('Note')) {
		# unless it somehow wasn't available for a previous transcript, 
		# but is now, we'll add it now
		# we won't check if transcripts for the same gene have the 
		# same note or not, why wouldn't they????
		if (defined $linedata->{note}) {
			# make note if it exists
			$gene->add_tag_value('Note', $linedata->{note});
		}
	} 
	
	return $gene;
}


sub generate_new_gene {
	my ($linedata, $id2count) = @_;
	
	# Set the gene name
	# in most cases this will be the name2 item from the gene table
	# except for some ncRNA and ensGene transcripts
	my ($name, $id, $alias);
	if ($ensembldata and exists $ensembldata->{ $linedata->{name} } ) {
		# we will automatically check ensembl data for a matching name 
		# this should not interfere with refGene names
		# not all ensGene names may use an ENS prefix, e.g. fly transcripts
		
		# we may not actually have a name though....
		if (defined $ensembldata->{ $linedata->{name} }->[0] ) {
			
			# use the common name as the gene name
			$name  = $ensembldata->{ $linedata->{name} }->[0];
			
			# use the name2 identifier as the ID
			$id = $linedata->{name2}; 
			
			# set the original identifier as an alias
			$alias = $linedata->{name2};
		}
		else {
			# use the name2 value
			$name = $linedata->{name2};
			$id   = $name;
		}
	}
	elsif (!defined $linedata->{name2}) {
		# some genes, notably some ncRNA genes, have no gene or name2 entry
		# we'll fake it and assign the transcript name
		# change it in linedata hash to propagate it in downstream code
		$linedata->{name2} = $linedata->{name};
		$name = $linedata->{name};
		$id   = $name;
	}
	else {
		# default for everything else
		$name = $linedata->{name2};
		$id   = $name;
	}
	
	# Uniqueify the gene ID
	# the ID will be based on the gene name and must be unique in the GFF file
	if (exists $id2count->{ lc $id }) {
		# we've encountered this transcript ID before
		
		# then make name unique by appending the count number
		$id2count->{ lc $id } += 1;
		$id .= '.' . $id2count->{ lc $id };
	}
	else {
		# this is the first transcript with this id
		# set the id counter
		$id2count->{lc $id} = 0;
	}
	
	
	# generate the gene SeqFeature object
	my $gene = Bio::SeqFeature::Lite->new(
		-seq_id        => $linedata->{chrom},
		-source        => $source,
		-primary_tag   => 'gene',
		-start         => $linedata->{txStart},
		-end           => $linedata->{txEnd},
		-strand        => $linedata->{strand},
		-phase         => '.',
		-display_name  => $name,
		-primary_id    => $id,
	);
	
	
	# add the original ENS* identifier as an Alias in addition to ID
	# for ensGene transcripts
	if ($alias) {
		$gene->add_tag_value('Alias', $alias);
	}
	
	# update extra attributes as necessary
	update_attributes($gene, $linedata);
	
	# finished
	return $gene;
}



sub generate_new_transcript {
	my ($linedata, $id2count, $gene) = @_;
	
	# Uniqueify the transcript ID and name
	my $id = $linedata->{name};
	if (exists $id2count->{ lc $id } ) {
		# we've encountered this transcript ID before
		
		# now need to make ID unique by appending a number
		$id2count->{ lc $id } += 1;
		$id .= '.' . $id2count->{ lc $id };
	}
	else {
		# this is the first transcript with this id
		$id2count->{lc $id} = 0;
	}
	
	# Generate the transcript SeqFeature object
	my $transcript = Bio::SeqFeature::Lite->new(
		-seq_id        => $linedata->{chrom},
		-source        => $source,
		-start         => $linedata->{txStart},
		-end           => $linedata->{txEnd},
		-strand        => $linedata->{strand},
		-phase         => '.',
		-display_name  => $linedata->{name},
		-primary_id    => $id,
	);
	
	# Attempt to identify the transcript type
	if ( $linedata->{cdsStart} - 1 == $linedata->{cdsEnd} ) {
		
		# there appears to be no coding potential when 
		# txEnd = cdsStart = cdsEnd
		# if you'll look, all of the exon phases should also be -1
		
		# check if we have a ensGene transcript, we may have the type
		if (
			$ensembldata and 
			exists $ensembldata->{ $linedata->{name} } and
			defined $ensembldata->{ $linedata->{name} }->[1]
		) {
			# this looks like an ensGene transcript
			# we just go ahead and check the ensembl data for a match
			# since not all ensGene names use the ENS prefix and are easily identified
			
			# these should be fairly typical standards
			# snRNA, rRNA, pseudogene, etc
			$transcript->primary_tag( 
				$ensembldata->{ $linedata->{name} }->[1] );
		}
		
		# otherwise, we may be able to infer some certain 
		# types from the gene name
		
		elsif ($linedata->{name2} =~ /^mir/i) {
			# a noncoding gene whose name begins with mir is likely a 
			# a micro RNA
			$transcript->primary_tag('miRNA');
		}
		elsif ($linedata->{name2} =~ /^snr/i) {
			# a noncoding gene whose name begins with snr is likely a 
			# a snRNA
			$transcript->primary_tag('snRNA');
		}
		elsif ($linedata->{name2} =~ /^sno/i) {
			# a noncoding gene whose name begins with sno is likely a 
			# a snoRNA
			$transcript->primary_tag('snoRNA');
		}
		else {
			# a generic ncRNA
			$transcript->primary_tag('ncRNA');
		}
	}
	else {
		# the transcript has an identifiable CDS
		$transcript->primary_tag('mRNA');
	}
	
	
	# add the Ensembl Gene name if it is an ensGene transcript
	if (
		$ensembldata and 
		exists $ensembldata->{ $linedata->{name} } and
		defined $ensembldata->{ $linedata->{name} }->[0]
	) {
		# if we have loaded the EnsemblGeneName data hash
		# we should be able to find the real gene name
		# we will put the common gene name as an alias
		$transcript->add_tag_value('Alias', 
			$ensembldata->{ $linedata->{name} }->[0] );
	}
	
	# add gene name as an alias
	if (defined $linedata->{name2}) {
		$transcript->add_tag_value('Alias', $linedata->{name2});
	}
	
	# update extra attributes as necessary
	update_attributes($transcript, $linedata);
	
	# add the completeness value for the tag
	if (defined $linedata->{completeness} ) {
		$transcript->add_tag_value( 'completeness', $linedata->{completeness} );
	}
	
	# add the completeness value for the tag
	if (defined $linedata->{status} ) {
		$transcript->add_tag_value( 'status', $linedata->{status} );
	}
	
	# add the exons
	add_exons($gene, $transcript, $linedata);
	
	# add CDS, UTRs, and codons if necessary
	if ($transcript->primary_tag eq 'mRNA') {
		
		if ($do_utr) {
			add_utrs($gene, $transcript, $linedata);
		}
		
		if ($do_codon) {
			add_codons($gene, $transcript, $linedata);
		}
		
		if ($do_cds) {
			add_cds($transcript, $linedata);
		}
	}
	
	# transcript is complete
	return $transcript;
}


sub update_attributes {
	my ($seqf, $linedata) = @_;
	
	# add Note if possible
	if (defined $linedata->{note} ) {
		add_unique_attribute($seqf, 'Note', $linedata->{note} );
	}
	
	# add refSeq identifier if possible
	if (defined $linedata->{refseq}) {
		add_unique_attribute($seqf, 'Dbxref', 'RefSeq:' . $linedata->{refseq});
	}
	
	# add SwissProt identifier if possible
	if (defined $linedata->{spid}) {
		add_unique_attribute($seqf, 'Dbxref', 'Swiss-Prot:' . $linedata->{spid});
	}
	
	# add SwissProt display identifier if possible
	if (defined $linedata->{spdid}) {
		add_unique_attribute($seqf, 'swiss-prot_display_id', $linedata->{spdid});
	}
	
	# add NCBI protein access identifier if possible
	if (defined $linedata->{protacc}) {
		add_unique_attribute($seqf, 'Dbxref', 'RefSeq:' . $linedata->{protacc});
	}
}


sub add_unique_attribute {
	my ($seqf, $tag, $value) = @_;
	
	# look for a pre-existing identical tag value
	my $check = 1;
	foreach ($seqf->get_tag_values($tag)) {
		if ($_ eq $value) {
			$check = 0;
			last;
		}
	}
	
	# add it if our value is unique
	$seqf->add_tag_value($tag, $value) if $check;
}


sub add_exons {
	my ($gene, $transcript, $linedata) = @_;
	
	
	# Add the exons
	for (my $i = 0; $i < $linedata->{exonCount}; $i++) {
		
		# first look for existing
		if ($recycle) {
			my $exon = find_existing_subfeature($gene, 'exon', 
				$linedata->{exonStarts}->[$i], $linedata->{exonEnds}->[$i]);
			if ($exon) {
				# we found an existing exon to reuse
				# associate with this transcript
				$transcript->add_SeqFeature($exon);
				next;
			}
		}
			
		# transform index for reverse strands
		# this will allow numbering from 5'->3'
		my $number; 
		if ($transcript->strand == 1) {
			# forward strand
			$number = $i;
		}
		else {
			# reverse strand
			$number = abs( $i - $linedata->{exonCount} + 1);
		}
		
		# build the exon seqfeature
		my $exon = Bio::SeqFeature::Lite->new(
			-seq_id        => $transcript->seq_id,
			-source        => $transcript->source,
			-primary_tag   => 'exon',
			-start         => $linedata->{exonStarts}->[$i],
			-end           => $linedata->{exonEnds}->[$i],
			-strand        => $transcript->strand,
			-primary_id    => $transcript->primary_id . ".exon$number",
		);
		
		# add name if requested
		if ($do_name) {
			$exon->display_name( $transcript->primary_id . ".exon$number" );
		}
		
		# associate with transcript
		$transcript->add_SeqFeature($exon);
	}
}



sub add_utrs {
	my ($gene, $transcript, $linedata) = @_;
	
	# we will scan each exon and look for a potential utr and build it
	my @utrs;
	for (my $i = 0; $i < $linedata->{exonCount}; $i++) {
		
		# transform index for reverse strands
		# this will allow numbering from 5'->3'
		my $number; 
		if ($transcript->strand == 1) {
			# forward strand
			$number = $i;
		}
		else {
			# reverse strand
			$number = abs( $i - $linedata->{exonCount} + 1);
		}
		
		# identify UTRs
		# we will identify by comparing the cdsStart and cdsStop relative
		# to the exon coordinates
		# the primary tag is determined by the exon strand orientation
		my ($start, $stop, $tag);
		# in case we need to build two UTRs
		my ($start2, $stop2, $tag2);
		
		# Split 5'UTR, CDS, and 3'UTR all on the same exon
		if (
			$linedata->{exonStarts}->[$i] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$i] > $linedata->{cdsEnd}
		) {
			# the CDS is entirely within the exon, resulting in two UTRs 
			# on either side of the exon
			# we must build two UTRs
			
			# the left UTR
			$start = $linedata->{exonStarts}->[$i];
			$stop  = $linedata->{cdsStart} - 1;
			$tag   = $transcript->strand == 1 ? 'five_prime_UTR' : 'three_prime_UTR';
			
			# the right UTR
			$start2 = $linedata->{cdsEnd} + 1;
			$stop2  = $linedata->{exonEnds}->[$i];
			$tag2   = $transcript->strand == 1 ? 'three_prime_UTR' : 'five_prime_UTR';
		}
		
		# 5'UTR forward, 3'UTR reverse
		elsif (
			$linedata->{exonStarts}->[$i] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$i] < $linedata->{cdsStart}
		) {
			# the exon start/end is entirely before the cdsStart
			$start = $linedata->{exonStarts}->[$i];
			$stop  = $linedata->{exonEnds}->[$i];
			$tag   = $transcript->strand == 1 ? 'five_prime_UTR' : 'three_prime_UTR';
		}
		
		# Split 5'UTR & CDS on forward, 3'UTR & CDS
		elsif (
			$linedata->{exonStarts}->[$i] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$i] >= $linedata->{cdsStart}
		) {
			# the start/stop codon is in this exon
			# we need to make the UTR out of a portion of this exon 
			$start = $linedata->{exonStarts}->[$i];
			$stop  = $linedata->{cdsStart} - 1;
			$tag   = $transcript->strand == 1 ? 'five_prime_UTR' : 'three_prime_UTR';
		}
		
		# CDS only
		elsif (
			$linedata->{exonStarts}->[$i] >= $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$i] <= $linedata->{cdsEnd}
		) {
			# CDS only exon
			next;
		}
		
		# Split 3'UTR & CDS on forward, 5'UTR & CDS
		elsif (
			$linedata->{exonStarts}->[$i] <= $linedata->{cdsEnd}
			and
			$linedata->{exonEnds}->[$i] > $linedata->{cdsEnd}
		) {
			# the stop/start codon is in this exon
			# we need to make the UTR out of a portion of this exon 
			$start = $linedata->{cdsEnd} + 1;
			$stop  = $linedata->{exonEnds}->[$i];
			$tag   = $transcript->strand == 1 ? 'three_prime_UTR' : 'five_prime_UTR';
		}
	
		# 3'UTR forward, 5'UTR reverse
		elsif (
			$linedata->{exonStarts}->[$i] > $linedata->{cdsEnd}
			and
			$linedata->{exonEnds}->[$i] > $linedata->{cdsEnd}
		) {
			# the exon start/end is entirely after the cdsStop
			# we have a 3'UTR
			$start = $linedata->{exonStarts}->[$i];
			$stop  = $linedata->{exonEnds}->[$i];
			$tag   = $transcript->strand == 1 ? 'three_prime_UTR' : 'five_prime_UTR';
		}
		
		# Something else?
		else {
			my $warning = "Here is an exon that doesn't match UTR criteria\n";
			foreach (sort {$a cmp $b} keys %$linedata) {
				if (ref $linedata->{$_} eq 'ARRAY') {
					$warning .= "  $_ => " . join(',', @{$linedata->{$_}}) . "\n";
				}
				else {
					$warning .= "  $_ => $linedata->{$_}\n";
				}
			}
			warn $warning;
			next;
		}
		
		## Generate the UTR objects
		my $utr;
			
		# look for existing utr
		if ($recycle) {
			$utr = find_existing_subfeature($gene, $tag, $start, $stop); 
		}
			
		# otherwise build the UTR object
		unless ($utr) {
			$utr = Bio::SeqFeature::Lite->new(
				-seq_id        => $transcript->seq_id,
				-source        => $transcript->source,
				-start         => $start,
				-end           => $stop,
				-strand        => $transcript->strand,
				-phase         => '.',
				-primary_tag   => $tag,
				-primary_id    => $transcript->primary_id . ".utr$number",
			);
			$utr->display_name( $transcript->primary_id . ".utr$number" ) if $do_name;
		}
		
		# store this utr seqfeature in a temporary array
		push @utrs, $utr;
		
		# build a second UTR object as necessary
		if ($start2) {
			my $utr2;
			
			# look for existing utr
			if ($recycle) {
				$utr2 = find_existing_subfeature($gene, $tag2, $start2, $stop2); 
			}
			
			# otherwise build the utr
			unless ($utr2) {
				$utr2 = Bio::SeqFeature::Lite->new(
					-seq_id        => $transcript->seq_id,
					-source        => $transcript->source,
					-start         => $start2,
					-end           => $stop2,
					-strand        => $transcript->strand,
					-phase         => '.',
					-primary_tag   => $tag2,
					-primary_id    => $transcript->primary_id . ".utr$number" . "a",
				);
				$utr2->display_name( $transcript->primary_id . ".utr$number" . "a" ) 
					if $do_name;
			}
		
			# store this utr seqfeature in a temporary array
			push @utrs, $utr2;
		}
	}
	
	# associate found UTRs with the transcript
	foreach my $utr (@utrs) {
		$transcript->add_SeqFeature($utr);
	}
}



sub add_cds {
	my ($transcript, $linedata) = @_;
	
	# we will NOT collapse CDS features since we cannot guarantee that a shared 
	# CDS will have the same phase, since phase is dependent on the translation 
	# start 
	
	# we will scan each exon and look for a potential CDS and build it
	my @cdss;
	my $phase = 0; # initialize CDS phase and keep track as we process CDSs 
	for (my $i = 0; $i < $linedata->{exonCount}; $i++) {
		
		# transform index for reverse strands
		my $j;
		if ($transcript->strand == 1) {
			# forward strand
			$j = $i;
		}
		else {
			# reverse strand
			# flip the index for exon starts and stops so that we 
			# always progress 5' -> 3' 
			# this ensures the phase is accurate from the start codon
			$j = abs( $i - $linedata->{exonCount} + 1);
		}
		
		# identify CDSs
		# we will identify by comparing the cdsStart and cdsStop relative
		# to the exon coordinates
		my ($start, $stop);
		
		# Split 5'UTR, CDS, and 3'UTR all on the same exon
		if (
			$linedata->{exonStarts}->[$j] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$j] > $linedata->{cdsEnd}
		) {
			# exon contains the entire CDS
			$start = $linedata->{cdsStart};
			$stop  = $linedata->{cdsEnd};
		}
		
		# 5'UTR forward, 3'UTR reverse
		elsif (
			$linedata->{exonStarts}->[$j] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$j] < $linedata->{cdsStart}
		) {
			# no CDS in this exon
			next;
		}
		
		# Split 5'UTR & CDS on forward, 3'UTR & CDS
		elsif (
			$linedata->{exonStarts}->[$j] < $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$j] >= $linedata->{cdsStart}
		) {
			# the start/stop codon is in this exon
			# we need to make the CDS out of a portion of this exon 
			$start = $linedata->{cdsStart};
			$stop  = $linedata->{exonEnds}->[$j];
		}
		
		# CDS only
		elsif (
			$linedata->{exonStarts}->[$j] >= $linedata->{cdsStart}
			and
			$linedata->{exonEnds}->[$j] <= $linedata->{cdsEnd}
		) {
			# entire exon is CDS
			$start = $linedata->{exonStarts}->[$j];
			$stop  = $linedata->{exonEnds}->[$j];
		}
	
		# Split 3'UTR & CDS on forward, 5'UTR & CDS
		elsif (
			$linedata->{exonStarts}->[$j] <= $linedata->{cdsEnd}
			and
			$linedata->{exonEnds}->[$j] > $linedata->{cdsEnd}
		) {
			# the stop/start codon is in this exon
			# we need to make the CDS out of a portion of this exon 
			$start = $linedata->{exonStarts}->[$j];
			$stop  = $linedata->{cdsEnd};
		}
	
		# 3'UTR forward, 5'UTR reverse
		elsif (
			$linedata->{exonStarts}->[$j] > $linedata->{cdsEnd}
			and
			$linedata->{exonEnds}->[$j] > $linedata->{cdsEnd}
		) {
			# the exon start/end is entirely after the cdsStop
			# we have entirely 5' or 3'UTR, no CDS
			next;
		}
		
		# Something else?
		else {
			my $warning = "Here is an exon that doesn't match CDS criteria\n";
			foreach (sort {$a cmp $b} keys %$linedata) {
				if (ref $linedata->{$_} eq 'ARRAY') {
					$warning .= "  $_ => " . join(',', @{$linedata->{$_}}) . "\n";
				}
				else {
					$warning .= "  $_ => $linedata->{$_}\n";
				}
			}
			warn $warning;
			next;
		}
			
		# build the CDS object
		my $cds = Bio::SeqFeature::Lite->new(
			-seq_id        => $transcript->seq_id,
			-source        => $transcript->source,
			-start         => $start,
			-end           => $stop,
			-strand        => $transcript->strand,
			# -phase         => $linedata->{exonFrames}->[$j],
			-phase         => $phase,
			-primary_tag   => 'CDS',
			-primary_id    => $transcript->primary_id . ".cds$i", 
			-display_name  => $transcript->primary_id . ".cds$i",
		);
		# the id and name still use $i for labeling to ensure numbering from 0
		
		# store this utr seqfeature in a temporary array
		push @cdss, $cds;
		
		# reset the phase for the next CDS
			# phase + (3 - (length % 3)), readjust to 0..2 if necessary
			# adapted from Barry Moore's gtf2gff3.pl script
		$phase = $phase + (3 - ( $cds->length % 3) );
		$phase -=3 if $phase > 2;
	}
	
	# associate found UTRs with the transcript
	foreach my $cds (@cdss) {
		$transcript->add_SeqFeature($cds);
	}
}



sub add_codons {
	
	my ($gene, $transcript, $linedata) = @_;
	
	# generate the start and stop codons
	my ($start_codon, $stop_codon);
	if ($transcript->strand == 1) {
		# forward strand
		
		# start codon
		$start_codon = find_existing_subfeature($gene, 'start_codon', 
			$linedata->{cdsStart}, $linedata->{cdsStart} + 2) if $recycle;
		
		unless ($start_codon) {
			$start_codon = Bio::SeqFeature::Lite->new(
					-seq_id        => $transcript->seq_id,
					-source        => $transcript->source,
					-primary_tag   => 'start_codon',
					-start         => $linedata->{cdsStart},
					-end           => $linedata->{cdsStart} + 2,
					-strand        => 1,
					-phase         => 0,
					-primary_id    => $transcript->primary_id . '.start_codon',
			);
			$start_codon->display_name( $transcript->primary_id . '.start_codon' ) if 
				$do_name;
		}
		
		# stop codon
		$stop_codon = find_existing_subfeature($gene, 'stop_codon', 
			$linedata->{cdsEnd} - 2, $linedata->{cdsEnd}) if $recycle;
		
		unless ($stop_codon) {
			$stop_codon = Bio::SeqFeature::Lite->new(
					-seq_id        => $transcript->seq_id,
					-source        => $transcript->source,
					-primary_tag   => 'stop_codon',
					-start         => $linedata->{cdsEnd} - 2,
					-end           => $linedata->{cdsEnd},
					-strand        => 1,
					-phase         => 0,
					-primary_id    => $transcript->primary_id . '.stop_codon',
			);
			$stop_codon->display_name( $transcript->primary_id . '.stop_codon' ) if 
				$do_name;
		}
	}
	
	else {
		# reverse strand
		
		# stop codon
		$stop_codon = find_existing_subfeature($gene, 'stop_codon', 
			$linedata->{cdsStart}, $linedata->{cdsStart} + 2) if $recycle;
		
		unless ($stop_codon) {
			$stop_codon = Bio::SeqFeature::Lite->new(
					-seq_id        => $transcript->seq_id,
					-source        => $transcript->source,
					-primary_tag   => 'stop_codon',
					-start         => $linedata->{cdsStart},
					-end           => $linedata->{cdsStart} + 2,
					-strand        => -1,
					-phase         => 0,
					-primary_id    => $transcript->primary_id . '.stop_codon',
			);
			$stop_codon->display_name( $transcript->primary_id . '.stop_codon' ) if 
				$do_name;
		}
		
		# start codon
		$start_codon = find_existing_subfeature($gene, 'start_codon', 
			$linedata->{cdsEnd} - 2, $linedata->{cdsEnd}) if $recycle;
		
		unless ($start_codon) {
			$start_codon = Bio::SeqFeature::Lite->new(
					-seq_id        => $transcript->seq_id,
					-source        => $transcript->source,
					-primary_tag   => 'start_codon',
					-start         => $linedata->{cdsEnd} - 2,
					-end           => $linedata->{cdsEnd},
					-strand        => -1,
					-phase         => 0,
					-primary_id    => $transcript->primary_id . '.start_codon',
					-display_name  => $transcript->primary_id . '.start_codon',
			);
			$start_codon->display_name( $transcript->primary_id . '.start_codon' ) if 
				$do_name;
		}
	}
	
	# associate with transcript
	$transcript->add_SeqFeature($start_codon);
	$transcript->add_SeqFeature($stop_codon);
}



sub find_existing_subfeature {
	my ($gene, $type, $start, $stop) = @_;
	
	# we will try to find a pre-existing subfeature at identical coordinates
	# to reuse
	my $feature;
	
	# walk through transcripts
	SUBF_LOOP: foreach my $transcript ($gene->get_SeqFeatures()) {
		
		# walk through subfeatures of transcripts
		foreach my $subfeature ($transcript->get_SeqFeatures()) {
			
			# test
			if (
				$subfeature->primary_tag eq $type and
				$subfeature->start == $start and 
				$subfeature->end   == $stop
			) {
				# we found a match
				$feature = $subfeature;
				last SUBF_LOOP;
			}
		}
	}
	
	return $feature;
}



sub print_current_gene_list {
	my ($gene2seqf, $gff_fh) = @_;
	
	# we need to sort the genes in genomic order before writing the GFF
	my %pos2seqf;
	print "  Sorting ", format_with_commas( scalar(keys %{ $gene2seqf }) ), 
		" top features....\n";
	foreach my $g (keys %{ $gene2seqf }) {
		
		# each value is an array of gene/transcripts
		foreach my $t ( @{ $gene2seqf->{$g} } ) {
		
			# get coordinates
			my $start = $t->start;
			my $chr;
			my $key;
			
			# identify which key to put under
			if ($t->seq_id =~ /^chr(\d+)$/i) {
				$chr = $1;
				$key = 'numeric_chr';
			}
			elsif ($t->seq_id =~ /^chr(\w+)$/i) {
				$chr = $1;
				$key = 'other_chr';
			}
			elsif ($t->seq_id =~ /(\d+)$/) {
				$chr = $1;
				$key = 'other_numeric';
			}
			else {
				$chr = $t->seq_id;
				$key = 'other';
			}
			
			
			# make sure start positions are unique, just in case
			# these modifications won't make it into seqfeature object
			while (exists $pos2seqf{$key}{$chr}{$start}) {
				$start++;
			}
			
			# store the seqfeature
			$pos2seqf{$key}{$chr}{$start} = $t;
		}
	}
	
	# print in genomic order
	# the gff_string method is undocumented in the POD, but is a 
	# valid method. Passing 1 should force a recursive action to 
	# print both parent and children.
	print "  Writing features to GFF....\n";
	foreach my $chr (sort {$a <=> $b} keys %{$pos2seqf{'numeric_chr'}} ) {
		foreach my $start (sort {$a <=> $b} keys %{ $pos2seqf{'numeric_chr'}{$chr} }) {
			# print the seqfeature recursively
			$pos2seqf{'numeric_chr'}{$chr}{$start}->version(3); 
			$gff_fh->print( $pos2seqf{'numeric_chr'}{$chr}{$start}->gff_string(1));
			
			# print directive to close out all previous features
			$gff_fh->print("\n###\n"); 
		}
	}
	foreach my $chr (sort {$a cmp $b} keys %{$pos2seqf{'other_chr'}} ) {
		foreach my $start (sort {$a <=> $b} keys %{ $pos2seqf{'other_chr'}{$chr} }) {
			$pos2seqf{'other_chr'}{$chr}{$start}->version(3); 
			$gff_fh->print( $pos2seqf{'other_chr'}{$chr}{$start}->gff_string(1));
			$gff_fh->print("\n###\n"); 
		}
	}
	foreach my $chr (sort {$a <=> $b} keys %{$pos2seqf{'other_numeric'}} ) {
		foreach my $start (sort {$a <=> $b} keys %{ $pos2seqf{'other_numeric'}{$chr} }) {
			$pos2seqf{'other_numeric'}{$chr}{$start}->version(3); 
			$gff_fh->print( $pos2seqf{'other_numeric'}{$chr}{$start}->gff_string(1));
			$gff_fh->print("\n###\n"); 
		}
	}
	foreach my $chr (sort {$a cmp $b} keys %{$pos2seqf{'other'}} ) {
		foreach my $start (sort {$a <=> $b} keys %{ $pos2seqf{'other'}{$chr} }) {
			$pos2seqf{'other'}{$chr}{$start}->version(3); 
			$gff_fh->print( $pos2seqf{'other'}{$chr}{$start}->gff_string(1));
			$gff_fh->print("\n###\n"); 
		}
	}
}



sub print_chromosomes {
	
	my $out_fh = shift;
	
	# open the chromosome file
	my $chromo_fh = open_to_read_fh($chromof) or die 
		"unable to open specified chromosome file '$chromof'!\n";
	
	# convert the chromosomes into GFF features
	# UCSC orders their chromosomes by chromosome length
	# I would prefer to order by numeric ID if possible
	my %chromosomes;
	while (my $line = $chromo_fh->getline) {
		next if ($line =~ /^#/);
		chomp $line;
		my ($chr, $end, $path) = split /\t/, $line;
		unless (defined $chr and $end =~ m/^\d+$/) {
			die " format of chromsome doesn't seem right! Are you sure?\n";
		}
		
		# generate seqfeature
		my $chrom = Bio::SeqFeature::Lite->new(
			-seq_id        => $chr,
			-source        => 'UCSC', # using a generic source here
			-primary_tag   => $chr =~ m/^chr/i ? 'chromosome' : 'scaffold',
			-start         => 1,
			-end           => $end,
			-primary_id    => $chr,
			-display_name  => $chr,
		);
		
		# store the chromosome according to name
		if ($chr =~ /^chr(\d+)$/i) {
			$chromosomes{'numeric_chr'}{$1} = $chrom;
		}
		elsif ($chr =~ /^chr(\w+)$/i) {
			$chromosomes{'other_chr'}{$1} = $chrom;
		}
		elsif ($chr =~ /(\d+)$/) {
			$chromosomes{'other_numeric'}{$1} = $chrom;
		}
		else {
			$chromosomes{'other'}{$chr} = $chrom;
		}
	}
	$chromo_fh->close;
	
	# print the chromosomes
	foreach my $key (sort {$a <=> $b} keys %{ $chromosomes{'numeric_chr'} }) {
		# numeric chromosomes
		$chromosomes{'numeric_chr'}{$key}->version(3);
		$out_fh->print( $chromosomes{'numeric_chr'}{$key}->gff_string . "\n" );
	}
	foreach my $key (sort {$a cmp $b} keys %{ $chromosomes{'other_chr'} }) {
		# other chromosomes
		$chromosomes{'other_chr'}{$key}->version(3);
		$out_fh->print( $chromosomes{'other_chr'}{$key}->gff_string . "\n" );
	}
	foreach my $key (sort {$a <=> $b} keys %{ $chromosomes{'other_numeric'} }) {
		# numbered contigs, etc
		$chromosomes{'other_numeric'}{$key}->version(3);
		$out_fh->print( $chromosomes{'other_numeric'}{$key}->gff_string . "\n" );
	}
	foreach my $key (sort {$a cmp $b} keys %{ $chromosomes{'other'} }) {
		# contigs, etc
		$chromosomes{'other'}{$key}->version(3);
		$out_fh->print( $chromosomes{'other'}{$key}->gff_string . "\n" );
	}
	
	# finished
	$out_fh->print( "###\n" );
}




__END__

=head1 NAME 

ucsc_table2gff3.pl

A script to convert UCSC gene tables to GFF3 annotation.

=head1 SYNOPSIS

   ucsc_table2gff3.pl --ftp <text> --db <text>
   
   ucsc_table2gff3.pl [--options] --table <filename>
  
  Options:
  --ftp [refgene|ensgene|xenorefgene|known|all]
  --db <text>
  --host <text>
  --table <filename>
  --status <filename>
  --sum <filename>
  --ensname <filename>
  --enssrc <filename>
  --kgxref <filename>
  --chromo <filename>
  --source <text>
  --(no)chr             (true)
  --(no)gene            (true)
  --(no)cds             (true)
  --(no)utr             (false)
  --(no)codon           (false)
  --(no)share           (true)
  --(no)name            (false)
  --gz
  --version
  --help

=head1 OPTIONS

The command line flags and descriptions:

=over 4

=item --ftp [refgene|ensgene|xenorefgene|known|all]

Request that the current indicated tables and supporting files be 
downloaded from UCSC via FTP. Four different tables may be downloaded, 
including I<refGene>, I<ensGene>, I<xenoRefGene> mRNA gene prediction 
tables, and the UCSC I<knownGene> table (if available). Specify all to 
download all four tables. A comma delimited list may also be provided.

=item --db <text>

Specify the genome version database from which to download the requested 
table files. See L<http://genome.ucsc.edu/FAQ/FAQreleases.html> for a 
current list of available UCSC genomes. Examples included hg19, mm9, and 
danRer7.

=item --host <text>

Optionally provide the host FTP address for downloading the current 
gene table files. The default is 'hgdownload.cse.ucsc.edu'.

=item --table <filename>

Provide the name of a UCSC gene or gene prediction table. Tables known 
to work include the I<refGene>, I<ensGene>, I<xenoRefGene>, and UCSC 
I<knownGene> tables. Both simple and extended gene prediction tables, as 
well as refFlat tables are supported. The file may be gzipped. When 
converting multiple tables, use this option repeatedly for each table. 
The C<--ftp> option is recommended over using this one.

=item --status <filename>

Optionally provide the name of the I<refSeqStatus> table file. This file 
provides additional information for the I<refSeq>-based gene prediction 
tables, including I<refGene>, I<xenoRefGene>, and I<knownGene> tables. 
The file may be gzipped. The C<--ftp> option is recommended over using this.

=item --sum <filename>

Optionally provide the name of the I<refSeqSummary> file. This file 
provides additional information for the I<refSeq>-based gene prediction 
tables, including I<refGene>, I<xenoRefGene>, and I<knownGene> tables. The 
file may be gzipped. The C<--ftp> option is recommended over using this.

=item --ensname <filename>

Optionally provide the name of the I<ensemblToGeneName> file. This file 
provides a key to translate the Ensembl unique gene identifier to the 
common gene name. The file may be gzipped. The C<--ftp> option is 
recommended over using this.

=item --enssrc <filename>

Optionally provide the name of the I<ensemblSource> file. This file 
provides a key to translate the Ensembl unique gene identifier to the 
type of transcript, provided by Ensembl as the source. The file may be 
gzipped. The C<--ftp> option is recommended over using this.

=item --kgxref <filename>

Optionally provide the name of the I<kgXref> file. This file 
provides additional information for the UCSC I<knownGene> gene table.
The file may be gzipped.

=item --chromo <filename>

Optionally provide the name of the chromInfo text file. Chromosome 
and/or scaffold features will then be written at the beginning of the 
output GFF file (when processing a single table) or written as a 
separate file (when processing multiple tables). The file may be gzipped.

=item --source <text>

Optionally provide the text to be used as the GFF source. The default is 
automatically derived from the source table file name, if recognized, or 
'UCSC' if not recognized.

=item --(no)chr

When downloading the current gene tables from UCSC using the C<--ftp> 
option, indicate whether (or not) to include the I<chromInfo> table. 
The default is true. 

=item --(no)gene

Specify whether (or not) to assemble mRNA transcripts into genes. This 
will create the canonical gene-E<gt>mRNA-E<gt>(exon,CDS) heirarchical 
structure. Otherwise, mRNA transcripts are kept independent. The gene name, 
when available, are always associated with transcripts through the Alias 
tag. The default is true.

=item --(no)cds

Specify whether (or not) to include CDS features in the output GFF file. 
The default is true.

=item --(no)utr

Specify whether (or not) to include three_prime_utr and five_prime_utr 
features in the transcript heirarchy. If not defined, the GFF interpreter 
must infer the UTRs from the CDS and exon features. The default is false.

=item --(no)codon

Specify whether (or not) to include start_codon and stop_codon features 
in the transcript heirarchy. The default is false.

=item --(no)share

Specify whether exons, UTRs, and codons that are common between multiple 
transcripts of the same gene may be shared in the GFF3. Otherwise, each 
subfeature will be represented individually. This will reduce the size of 
the GFF3 file at the expense of increased complexity. If your parser 
cannot handle multiple parents, set this to --noshare. Due to the 
possibility of multiple translation start sites, CDS features are never 
shared. The default is true.

=item --(no)name

Specify whether you want subfeatures, including exons, CDSs, UTRs, and 
start and stop codons to have display names. In most cases, this 
information is not necessary. The default is false.

=item --gz

Specify whether the output file should be compressed with gzip.

=item --version

Print the version number.

=item --help

Display the POD documentation

=back

=head1 DESCRIPTION

This program will convert a UCSC gene or gene prediction table file into a
GFF3 format file. It will build canonical gene-E<gt>transcript-E<gt>[exon, 
CDS, UTR] heirarchical structures. It will attempt to identify non-coding genes
as to type using the gene name as inference. Various additional
informational attributes may also be included with the gene and transcript
features, which are derived from supporting table files.

Four table files are supported. Gene prediction tables, including I<refGene>, 
I<xenoRefGene>, and I<ensGene>, are supported. The UCSC I<knownGene> gene 
table, if available, is also supported. Supporting tables include I<refSeqStatus>, 
I<refSeqSummary>, I<ensemblToGeneName>, I<ensemblSource>, and I<kgXref>. 

Tables obtained from UCSC are typically in the extended GenePrediction 
format, although simple genePrediction and refFlat formats are also 
supported. See L<http://genome.ucsc.edu/FAQ/FAQformat.html#format9> regarding
UCSC gene prediction table formats. 

The latest table files may be automatically downloaded using FTP from 
UCSC or other host. Since these files are periodically updated, this may 
be the best option. Alternatively, individual files may be specified 
through command line options. Files may be obtained manually through FTP, 
HTTP, or the UCSC Table Browser. However, it is B<highly recommended> to 
let the program obtain the necessary files using the C<--ftp> option, as 
using the wrong file format or manipulating the tables may prevent the 
program from working properly.

If provided, chromosome and/or scaffold features may also be written to a 
GFF file. If only one table is being converted, then the chromosome features 
are prepended to the GFF file; otherwise, a separate chromosome GFF file is 
written.

If you need to set up a database using UCSC annotation, you should first 
take a look at the BioToolBox script B<db_setup.pl>, which provides a 
convenient automated database setup based on UCSC annotation. You can also 
find more information about loading a database in a How To document at 
L<https://code.google.com/p/biotoolbox/wiki/WorkingWithDatabases>. 

=head1 AUTHOR

 Timothy J. Parnell, PhD
 Dept of Oncological Sciences
 Huntsman Cancer Institute
 University of Utah
 Salt Lake City, UT, 84112

This package is free software; you can redistribute it and/or modify
it under the terms of the GPL (either version 1, or at your option,
any later version) or the Artistic License 2.0.  
