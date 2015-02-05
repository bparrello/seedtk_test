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

=head1 Shrub Genome Loader

	ShrubLoadGenomes [options] directory genome1 genome2 ...
	
This method loads one or more genomes from repository directories into the
Shrub database. The genome data will be assembled into load files for
each table, and then the tables loaded directly from the files.

The positional parameters are the name of the directory containing the
genome exchange directories, plus the names of the genomes to be loaded.
The command-line parameters listed in L<Shrub/new_for_script> are accepted
as well as the following.

=over 4

=item slow

Load the database with individual inserts instead of a table load.

=item missing

Load only genomes that are not already in the database.

=item clear

Truncate the tables before loading.

=item genomes

If specified, the name of a file containing a list of genome IDs. Genomes from this list will be loaded in
addition to any specified in the argument list. Mutually exclusive with C<all>.

=item override

If specified, new function assignments will overwrite existing function assignments. Otherwise, new
function assignments will be ignored.

=item all

Load all of the genomes in the genome directory. Mutually exclusive with C<genomes>.

=back

=cut

	use strict;
	use Shrub;
	use ShrubLoader;
	use ShrubFunctionLoader;
	use File::Path ();
	use File::Copy ();
	use MD5Computer;
	
	# This is the list of tables we are loading.
	use constant LOADTABLES => qw(Genome Genome2Contig Contig Genome2Feature Feature Feature2Contig Feature2Function);
	
	# Start timing.
	my $startTime = time;
	$| = 1; # Prevent buffering on STDOUT.
	# Connect to the database.
	print "Connecting to database.\n";
	my ($shrub, $opt) = Shrub->new_for_script('%c %o genomeDirectory genome1 genome2 ...', { },
			["privilege|p=i", "privilege level for assignments", { default => 0 }],
			["slow|s", "use individual inserts rather than table loads"],
			["genomes=s", "name of a file containing a list of the genomes to load"],
			["missing|m", "only load genomes not already in the database"],
			["override|o", "override existing protein function assignments"],
			["clear|c", "clear the genome tables before loading", { implies => 'missing' }],
			["all|a", "process all genomes in the genome directory"],
		);
	# We are connected. Create the loader utility object.
	my $loader = ShrubLoader->new($shrub);
	# Get the statistics object.
	my $stats = $loader->stats;
	# Get the positional parameters.
	my ($genomeDir, @genomes) = @ARGV;
	# Verify the genome directory.
	if (! $genomeDir) {
		die "No genome directory specified.";
	} elsif (! -d $genomeDir) {
		die "Invalid genome directory $genomeDir.";
	}
	# Get the list of genomes to load. We will store it in $genomeHash, as a hash mapping
	# genome IDs to directories.
	print "Reading genome repository.\n";
	my $genomeHash = $loader->FindGenomeList($genomeDir);
	if ($opt->all) {
		if (scalar @genomes || $opt->genomes) {
			die "ALL option specified along with a list of genome IDs. Use one or the other.";
		}
	} else {
		# Here we are only doing some of the genomes. We'll put them in here.
		my $genomeList = [@genomes];
		# First, do we have a list file?
		if ($opt->genomes) {
			# Yes. Get the genomes in the list.
			my $genomeData = $loader->GetNamesFromFile($opt->genomes, 'genome');
			push @$genomeList, @$genomeData;
		}
		# Now run through the genome list. If one of them is not in the repository, throw an error.
		# Otherwise, put it into a hash.
		my %genomeMap;
		for my $genome (@$genomeList) {
			my $genomeLoc = $genomeHash->{$genome};
			if (! $genomeLoc) {
				die "Genome $genome not found in repository.";
			} else {
				$genomeMap{$genome} = $genomeLoc;
			}
		}
		# Save the genome map.
		$genomeHash = \%genomeMap;
	}
	# Now "$genomeHash" contains a hash mapping the genomes we want to process to their directories.
	print "Initializing function and role tables.\n";
	# Create the function loader utility object.
	my $funcLoader = ShrubFunctionLoader->new($loader);
	# Extract the privilege level.
	my $priv = $opt->privilege;
	if ($priv > Shrub::MAX_PRIVILEGE || $priv < 0) {
		die "Invalid privilege level $priv.";
	}
	print "Privilege level is $priv.\n";
	# Are we clearing?
	if ($opt->clear) {
		# Yes. The MISSING option is invalid.
		if ($opt->missing) {
			die "Cannot specify MISSING when CLEAR is used.";
		} else {
			print "CLEAR option specified.\n";
			$loader->Clear(LOADTABLES);
		}
	}
	# If we are NOT in slow mode, prepare the tables for loading.
	if (! $opt->slow) {
		$loader->Open(LOADTABLES);
	}
	# If we want to override function assignments, put the function relationships in replace mode.
	if ($opt->override) {
		$loader->ReplaceMode(qw(Feature2Function Protein2Function));
	}
	# The next step is to resolve collisions. The following method will check for duplicate genomes and
	# delete existing genomes that conflict with the incoming ones. At the end, $genomeMeta will be a
	# hash mapping the ID of each genome we need to process to it metadata.
	my $genomeMeta = $loader->CurateNewGenomes($genomeHash, $opt->missing, $opt->clear);
	# Get the DNA repository directory.
	my $dnaRepo = $shrub->DNArepo;
	# Loop through the incoming genomes.
 	for my $genome (sort keys %$genomeHash) {
 		print "Processing $genome.\n";
 		my $metaHash = $genomeMeta->{$genome};
 		if ($metaHash) {
	 		# Get the input repository directory.
	 		my $genomeLoc = $genomeHash->{$genome};
	 		# Read the metadata.
	 		my $metaHash = $loader->ReadMetaData("$genomeLoc/genome-info", required => [qw(type name)]);
	 		# Parse the genome name.
	 		my ($genus, $species) = split /\s+/, $metaHash->{name};
	 		# Form the repository directory for the DNA.
	 		my $relPath = "$genus/species";
	 		my $absPath = "$dnaRepo/$genus/$species";
	 		if (! -d $absPath) {
	 			print "Creating directory $relPath for DNA file.\n";
	 			File::Path::make_path($absPath);
	 		}
	 		print "Copying contig file.\n";
	 		File::Copy::copy("$genomeLoc/contigs", "$absPath/$genome.fa") ||
	 			die "Could not copy contig file from $genomeLoc: $!";
	 		# Now we read the contig file and analyze the DNA for gc-content, number
	 		# of bases, and the list of contigs.
	 		print "Analyzing contigs.\n";
	 		my $gcCount = 0;
	 		my $dnaCount = 0;
	 		my $contigCount = 0;
	 		my $md5Thing = MD5Computer->new();
	 		# This list will contain a hash of the fields in each contig record. We
	 		# will insert the contigs after we have all the information about the
	 		# genome's DNA computed so we can insert the genome record first.
	 		my @contigData;
	 		# Open the contig file.
	 		my $fh = $loader->OpenFasta("$absPath/$genome.fa");
	 		# Loop through the contigs.
	 		while (my $contigInfo = $loader->GetLine($fh)) {
	 			my ($contigID, undef, $seq) = @$contigInfo;
	 			$stats->Add(contigs => 1);
	 			# Compute the contig MD5.
	 			my $contigMD5 = $md5Thing->ProcessContig($contigID, [$seq]);
	 			# Get its length.
	 			my $contigLen = length $seq;
	 			$stats->Add(dnaBases => $contigLen);
	 			# Accumulate the genome statistics.
	 			$gcCount += ($seq =~ tr/GCgc//);
	 			$dnaCount += $contigLen;
	 			$contigCount++;
	 			# Save the contig information.
	 			push @contigData, { id => "$genome:$contigID", length => $contigLen, 'md5-identifier' => $contigMD5 };
	 		}
	 		# Now we can create the genome record.
	 		print "Storing $genome in database.\n";
	 		$loader->InsertObject('Genome', id => $genome, contigs => $contigCount,
	 				core => $metaHash->{type}, 'dna-size' => $dnaCount, 'gc-content' => ($gcCount * 100 / $dnaCount),
	 				'md5-identifier' => $md5Thing->genomeMD5(), name => $metaHash->{name},
	 				'contig-file' => "$relPath/$genome.fa");
	 		$stats->Add(genomeInserted => 1);
	 		# Connect the contigs to it.
	 		for my $contigDatum (@contigData) {
	 			$loader->InsertObject('Genome2Contig', 'from-link' => $genome, 'to-link' => $contigDatum->{id});
	 			$loader->InsertObject('Contig', %$contigDatum);
	 			$stats->Add(contigInserted => 1);
	 		}
	 		# Process the non-protein features.
	 		my $npFile = "$genomeLoc/non-peg-fids";
	 		if (-f $npFile) {
	 			# Read the feature data.
	 			print "Processing non-protein features.\n";
	 			my $pegHash = $funcLoader->ReadFeatures($genome, $npFile);
	 			# Connect the functions.
	 			print "Connecting to functions.\n";
	 			for my $fid (keys %$pegHash) {
	 				my $function = $pegHash->{$fid};
	 				# Compute this function's ID.
	 				my ($funcID, $comment) = $funcLoader->ProcessFunction($function);
	 				# Make the connection at each privilege level.
	 				for (my $p = $priv; $p >= 0; $p--) {
	 					$loader->InsertObject('Feature2Function', 'from-link' => $fid, 'to-link' => $funcID,
	 							comment => $comment, security => $p);
	 					$stats->Add(featureFunction => 1);
	 				}
	 			}
	 		}
	 		print "Processing protein features.\n";
	 		my $pegHash = $funcLoader->ReadFeatures($genome, "$genomeLoc/peg-info");
	 		print "Connecting to functions.\n";
	 		$funcLoader->ConnectPegFunctions($genome, $genomeLoc, $pegHash, priv => $priv);
 		}
 	}
 	# All done. Print the statistics.
 	my $totalTime = time - $startTime;
 	my $genomeCount = scalar keys %$genomeHash;
 	if ($genomeCount > 0) {
 		my $perGenome = ($totalTime / $genomeCount);
 		print "$perGenome seconds per genome.\n";
 	}
 	$stats->Add(totalTime => $totalTime);
 	print "All done.\n" . $stats->Show();
 
 