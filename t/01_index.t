#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/dirname/;
use FindBin qw/$RealBin/;
use Data::Dumper;

use Test::More tests => 2;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

diag `template.pl -h`;
my $exit_code = $? << 8;
is($exit_code, 0, "exit code");

subtest 'kraken2' => sub {
    mkdir "$RealBin/data/workdir";

    # Make the chimera file
    my $chimera = "$RealBin/data/workdir/chimera.fasta";
    open(my $fh, '>', $chimera) or die "Could not write to '$chimera' $!";
    print $fh ">chimera_of_K12_and_MN908947\n";
    for my $asm("$RealBin/data/K12.fasta", "$RealBin/data/MN908947.fasta") {
        open(my $fh2, '<', $asm) or die "Could not read '$asm' $!";
        while(<$fh2>) {
            next if(/^>/);
            print $fh $_;
        }
        close $fh2;
    }
    close $fh;
    isnt(-s $chimera, 0, "chimera file is empty");

    # Run kraken
    my $out = "$RealBin/data/workdir/kraken.out";
    my $cmd = "kraken2 -db $RealBin/data/kraken_db $chimera > $out";
    is(system($cmd), 0, "kraken2");

    # kraken.out now has a file with, e.g., 
    #    C	chimera_of_K12_and_MN908947	562	4671555	562:14 0:35 562:121 0:63 562:34 0:40
    # And now we need to translate all of that to the species or genus level,
    # probably using taxonkit.
    # Then find if it changes over to a totally different taxon at some point.
}