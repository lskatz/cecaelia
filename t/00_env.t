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

subtest 'build kraken' => sub {

    # If the kraken database already exists, then skip this test
    my $db = "$RealBin/data/kraken_db";
    if(-d $db) {
        pass("kraken database already exists");
        return;
    }

    # Make a small kraken database
    # First, make an empty folder
    mkdir $db;
    mkdir "$db/taxonomy";
    # Then, download the taxonomy into it by downloading from the ftp site
    my $cmd = "wget https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz -O $db/taxonomy/taxdump.tar.gz";
    system($cmd);
    system("cd $db/taxonomy && tar -xzf taxdump.tar.gz");

    # Next, add K12 and MN908947 to the database
    # These genomes are E. coli and SARS-CoV-2, respectively
    for my $asm("$RealBin/data/K12.fasta", "$RealBin/data/MN908947.fasta") {
        $cmd = "kraken2-build --add-to-library $asm --db $db";
        is(system($cmd), 0, "kraken2-build --add-to-library $asm");
    }
    # Build the database
    $cmd = "kraken2-build --build --db $db";
    is(system($cmd), 0, "kraken-build --build");
    system("kraken2-build --clean --db $db");
}