#!/usr/bin/env run_perl.sh

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
    use CGI;


=head1 ERDB DBD Display

=head2 Introduction

This script outputs the XML definition file of an L<ERDB> database. The
definition file is located and then output directly; this allows us
to pass the DBD to the Flash documentation program.

The script parameters are as follows:

=over 4

=item xmlFileName

Name of the DBD file to be output.

=back

=cut

# Get the CGI query object.
my $cgi = CGI->new();
# Get the parameters.
my $fileName = $cgi->param('xmlFileName');
if (! $fileName) {
    die "No DBD specified.";
} elsif (! -f $fileName) {
    die "Invalid DBD location $fileName.";
} else {
    # Start the output.
    print "Content-Type: text/xml\n\n";
    # Open the XML file.
    open(my $ih, "<$fileName") || die "Could not open $fileName: $!";
    # Echo it to the outut.
    while (! eof $ih) {
        my $line = <$ih>;
        print $line;
    }
    # Close the input file.
    close $ih;
}
