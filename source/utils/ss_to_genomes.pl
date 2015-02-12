#!/usr/bin/env perl

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

=head1 Display Genomes for a given subsystem

    ss_to_genomes [options] < Subsystems

This is a simple script that prints the genomes represented in each of a set 
of subsystems.

=head2 Parameters

There are no positional parameters.

The command-line options are those found in L<Shrub/new_for_script>.

=cut

use strict;
use Data::Dumper;;
use Shrub;

# Connect to the database.
my ($shrub, $opt) = Shrub->new_for_script('%c %o', { });

while (defined($_ = <STDIN>))
{
    if ($_ =~ /^(\S.*\S)/)
    {
	my $ss = $1;
        my @tuples = $shrub->GetAll("Subsystem Subsystem2Genome Genome", 
				    "Subsystem(id) = ?",[$ss],
				    "Subsystem(id) Genome(id) Genome(name)");
        print &Dumper(\@tuples); die "HERE";
    }
}

