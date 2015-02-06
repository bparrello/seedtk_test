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
    use Shrub;
    use Tracer;

	$| = 1; # Prevent buffering on STDOUT.
	# Connect to the database.
	my ($shrub, $opt) = Shrub->new_for_script('%c %o', {}); 
	my @roles = $shrub->GetAll('Role', 'Role(ec-number) <> ?', [''], 'id ec-number statement');
	for my $role (@roles) {
		print Tracer::Pad($role->[0], 10, 1) . ". " . Tracer::Pad($role->[1], 12) . " $role->[2]\n";
	}
 