#!/usr/bin/env perl

#
use Getopt::Long;
use strict;
use warnings;

use File::Basename;
use Carp;
use Data::Dumper;

use Bio::SeqIO;

use Motif;

my $words = "";
my $noRepeatMask = 0;
my $singleLine = 0;
my $noDesc = 0;

my $noAmbiguous = 0;
my $maxRepeat = 0;
my $verbose = 0;
my $prog = basename ($0);



GetOptions ('w|words:s'=>\$words,
		'nr'=>\$noRepeatMask,
		's'=>\$singleLine,
		'no-desc'=>\$noDesc,
		'no-N'=>\$noAmbiguous,
		'max-repeat:f'=>\$maxRepeat,
		'v'=>\$verbose);

if (@ARGV != 2)
{
	print "mask repetitive (small letter) or particular sequences\n";
	print "Usage: $prog [options] <in.fa> <out.fa>\n";
   	print " in.fa can be '-' for stdin\n";
    print " out.fa can be '-' for stdout\n";
	print "OPTIONS:\n";
	print " -w  [string]: words separated by ',' or a file name\n";
	print " -nr                 : no repeat masking\n";
	print " --no-N              : no sequences with N (after masking)\n";
	print " --max-repeat [float]: max proportion of repeat masked sequences in small letters (default=no requirement)\n"; 
	print " -s                  : print each sequence in a single line\n";
	print " --no-desc           : does not print description in header line\n";
	print " -v                  : verbose\n";
	exit (1);
}


my ($inFastaFile, $outFastaFile) = @ARGV;

my $msgio = $outFastaFile eq '-' ? *STDERR : *STDOUT;

my %wordHash;

if (-f $words)
{
	print $msgio "reading words to be masked from $words ...\n" if $verbose;
	my $fin;
	open ($fin, "<$words") || Carp::croak "can not open file $words to read\n";
	while (my $line = <$fin>)
	{
		chomp $line;
		next if $line =~/^\s*$/;
		$wordHash {$line} = 1;
	}
	close ($fin);
}
else
{
	my @cols = split (/\,/, $words);
	foreach my $w (@cols)
	{
		$wordHash {$w} = 1;
	}
}

my $n = keys %wordHash;

print $msgio "$n words to be masked ...\n" if $verbose;


my ($seqIn, $seqOut);

if ($inFastaFile ne '-')
{
    $seqIn = Bio::SeqIO->new (-file => $inFastaFile,
        -format => 'Fasta');
}
else
{
    $seqIn = Bio::SeqIO->new (-fh => \*STDIN,
        -format => 'Fasta');
}

if ($outFastaFile ne '-')
{
    $seqOut = Bio::SeqIO->new (-file => ">$outFastaFile",
        -format => 'Fasta');
}
else
{
    $seqOut = Bio::SeqIO->new (-fh => \*STDOUT,
        -format => 'Fasta');
}



my $seq;
while ($seq = $seqIn->next_seq())
{
	my $seqStr = $seq->seq ();

	foreach my $w (keys %wordHash)
	{
		$seqStr = maskWord ($seqStr, $w);
	}

	if ($maxRepeat > 0)
	{
		my $nrmsk = ($seqStr=~tr/acgtn//);
		next if $nrmsk / length($seqStr) > $maxRepeat;
	}

	$seqStr =~tr/a-z/n/ unless $noRepeatMask;
	
	if ($noAmbiguous)
	{
		next if $seqStr =~/[^ACGTacgt]/;
	}



	$seq->seq ($seqStr);
	if ($singleLine)
	{
		my $len = $seq->length();
		$seqOut->width ($len);
	}
	$seq->desc ("") if $noDesc;
	$seqOut->write_seq ($seq);
}		




