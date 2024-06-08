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
            my(undef, $scinames, $taxids, $ranks) = split(/\t/, $lineage);
            my @sciname = split(/;/, $scinames);
            my @rank = split(/;/, $ranks);
            my @taxid = split(/;/, $taxids);
            for(my $i=0; $i<@rank; $i++){
                $rank{$rank[$i]} = $taxid[$i];
                $rank{$rank[$i]} //= 0; # set to 0 if not defined
            }
            push(@taxidsAlongSeq, $rank{$targetRank});
        }
        die Dumper \@taxidsAlongSeq;
    }
}

sub usage{
  print "$0: does something
  Usage: $0 [options] arg1
  --help   This useful help menu
  \n";
  exit 0;
}
