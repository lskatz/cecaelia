#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename qw/dirname/;
use FindBin qw/$RealBin/;
use lib "$RealBin/../lib/perl5";
use Data::Dumper;

use Test::More tests => 2;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

diag `cecaelia.pl -h`;
my $exit_code = $? << 8;
is($exit_code, 0, "exit code");

subtest 'kraken2' => sub {
    mkdir "$RealBin/data/workdir";

    # Make the chimera file
    my $chimera = "$RealBin/data/workdir/chimera.fasta";
    open(my $fh, '>', $chimera) or die "Could not write to '$chimera' $!";
    my $numBp = 1000; # number of bp to extract from each genome
    print $fh ">chimera_of_K12_and_MN908947 $numBp nucleotides from each assembly\n";
    for my $asm("$RealBin/data/K12.fasta", "$RealBin/data/MN908947.fasta") {
        my $fastaStr = "";
        open(my $fh2, '<', $asm) or die "Could not read '$asm' $!";
        # read the fasta file into memory
        my $seqname = <$fh2>;
        my $sequence = <$fh2>;
        while(length($sequence) < $numBp){
            $sequence .= <$fh2>;
            # TODO if needed: detect EOF for $fh2
        }
        $sequence =~ s/\s+//g;
        $sequence = substr($sequence, 0, $numBp);
        print $fh $sequence ."\n";
        close $fh2;
    }
    close $fh;
    isnt(-s $chimera, 0, "chimera file isn't empty");

    # Run kraken
    my $out = "$RealBin/data/workdir/kraken.out";
    my $cmd = "kraken2 --db $RealBin/data/kraken_db $chimera > $out";
    is(system($cmd), 0, "kraken2");

    system("cecaelia.pl $out");
}