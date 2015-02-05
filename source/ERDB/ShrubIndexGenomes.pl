#!/usr/bin/perl -w

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

    use strict;
    use Stats;
    use SeedUtils;
    use ShrubLoader;
    use Shrub;

=head1 Shrub Genome Source Repository Index Creator

    ShrubIndexGenomes [options] genomeDirectory

This script reads the hierarchy of a genome repository and creates its index file.

This script loads the DBD but does not connect to the database.

The command-line options are as specified in L<Shrub/new_for_script>. The positional
parameter is the name of the genome directory.

=cut

	$| = 1; # Prevent buffering on STDOUT.
	# Connect to the database.
	my ($shrub, $opt) = Shrub->new_for_script('%c %o genomeDIrectory', { offline => 1 });
    # Create the loader object.
    my $loader = ShrubLoader->new($shrub);
    my $stats = $loader->stats;
    # Insure we have a genome directory.
    my ($genomeDir) = $ARGV[0];
    if (! $genomeDir) {
    	die "No genome directory specified.";
    } elsif (! -d $genomeDir) {
    	die "Invalid genome directory $genomeDir.";
    }
    # Open the output file.
    open(my $oh, ">$genomeDir/index") || die "Could not open index file for output: $!";
    # Get the length of the repository directory name.
    my $repoNameLen = length($genomeDir);
    # Read the genome list. Note we suppress use of the index if it's already there.
    print "Reading genome directory $genomeDir.\n";
    my $genomeDirs = $loader->FindGenomeList($genomeDir, useDirectory => 1);
    # Loop through the genomes.
    for my $genome (sort keys %$genomeDirs) {
    	# Get this genome's directory.
    	my $genomeLoc = $genomeDirs->{$genome};
    	# Read its metadata.
    	my $metaHash = $loader->ReadMetaData("$genomeLoc/genome-info", required => 'name');
    	# Relocate the directory so that it is relative to the repository.
    	$genomeLoc = substr($genomeLoc, $repoNameLen + 1);
    	# Write the ID, name, and directory to the output file.
    	print $oh join("\t", $genome, $metaHash->{name}, $genomeLoc) . "\n";
    	$stats->Add(genomeOut => 1);
    }
    # Close the output file.
    close $oh;
    # Tell the user we're done.
    print "Directory processed.\n" . $stats->Show();

