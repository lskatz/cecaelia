#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use FindBin qw/$RealBin/;
use lib "$RealBin/../lib/perl5";

use Statistics::ChiSquare qw/chisquare/;

use version 0.77;
our $VERSION = '0.1.1';

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});

  for my $infile(@ARGV){
    testForUnevenness($infile, $settings);
  }

  return 0;
}

sub testForUnevenness{
  my($infile, $settings) = @_;
    # kraken.out now has a file with, e.g., 
    #    C	chimera_of_K12_and_MN908947	562	4671555	562:14 0:35 562:121 0:63 562:34 0:40
    # And now we need to translate all of that to the species or genus level,
    # using taxonkit.
    my $targetRank = 'species';
    # Cache taxonkit results
    my %taxonkitLineageCache;
    open(my $krakenFh, '<', $infile) or die "Could not read '$infile' $!";
    while(my $line = <$krakenFh>){
        chomp $line;
        my($classified, $seqname, $consensusTaxid, $seqlength, $kraken_line) = split(/\t/, $line);
        # Make an array of taxids at the target rank 
        my @taxidsAlongSeq;
        for my $lcaMapping(split(/ +/, $kraken_line)){
            my($taxid, $count) = split(/:/, $lcaMapping);

            # Take care of the special case where Kraken didn't classify, 
            # which is indicated with 0
            if($taxid == 0){
                push(@taxidsAlongSeq, $taxid);
                next;
            }

            # Make a hash of $rank => $taxid
            my %rank;
            my $lineage = $taxonkitLineageCache{$taxid};
            if(!defined($lineage)){
                logmsg "Taxonkit lineage -R with $taxid";
                $lineage = `echo $taxid | taxonkit lineage -R -t`;
                chomp($lineage);
                $taxonkitLineageCache{$taxid} = $lineage;
            } 

            # Parse the lineage. Might want to cache this part later if I want to eek out a little more speed.
            my(undef, $scinames, $taxids, $ranks) = split(/\t/, $lineage);
            my @sciname = split(/;/, $scinames);
            my @rank = split(/;/, $ranks);
            my @taxid = split(/;/, $taxids);
            for(my $i=0; $i<@rank; $i++){
                $rank{$rank[$i]} = $taxid[$i];
                $rank{$rank[$i]} //= 0; # set to 0 if not defined
            }
            for(1..$count){
              push(@taxidsAlongSeq, $rank{$targetRank});
            }
        }
        
        # make the chi square table.
        # Pick a position and then how many flanking positions to look at
        my $position = 10;
        my $flank = 5;
        my $start = $position - $flank;
        my $stop  = $position + $flank;

        # Get the "before" and "after"
        my %countsBefore;
        my %countsAfter;
        for my $i($start..$position-1){
            my $taxid = $taxidsAlongSeq[$i];
            $countsBefore{$taxid}++;
        }
        for my $i($position+1..$stop){
            my $taxid = $taxidsAlongSeq[$i];
            $countsAfter{$taxid}++;
        }

        my @chiTable;
        push(@chiTable, keys(%countsBefore));
        push(@chiTable, keys(%countsAfter));
        print Dumper [$position,$flank, \%countsBefore, \%countsAfter, \@chiTable, [chisquare(@chiTable)]];
    }
}

sub usage{
  print "$0: does something
  Usage: $0 [options] arg1
  --help   This useful help menu
  \n";
  exit 0;
}
