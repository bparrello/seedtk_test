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
use lib::Web_Config;
use Tracer qw(:DEFAULT PrintLine);
use Shrub;
use ERDBPDocPage;
use ERDBExtras;

=head1 ErdbDocWidget Script

This is a small script that generates the documentation widget for an ERDB
database. It is designed to fit inside an embedded frame. The widget appears as
a two-column table with a scrolling select control on the left and the
documentation for the selected component on the right.

The following CGI parameters are used.

=over 4

=item database

Name of the database to document.

=item xmlFileName

Name of the XML file to document. If this option is specified, it overrides
B<database>. In this case, it is presumed the documentation is for a database
in development rather than a live database.

=item rows

The estimated number of rows to display in the select box in order to make the
widget fit comfortably inside the frame.

=back

=cut

# Get the CGI query object.
my $cgi = CGI->new();
# Start the output page.
print CGI::header();
print CGI::start_html(-title => 'ERDB Database Documenter',
                      -style =>  { src => "css/ERDB.css" },
                      -script => { src => "lib/ERDB.js" });
# Insure we recover from errors.
eval {
    # Get the parameters.
    my $height = $cgi->param('height') || 900;
    my $xmlFileName = $cgi->param('xmlFileName') || $FIG_Config::shrub_dbd;
    # Get the datanase object.
    my $erdb;
    if ($xmlFileName) {
        # Yes, get a pseudo-database object for that XML file.
        $erdb = Shrub->new(DBD => $xmlFileName, offline => 1);
    } else {
        # No, get the live database.
        $erdb = Shrub->new();
    }
    # Get a page creator.
    my $page = ERDBPDocPage->new(dbObject => $erdb);
    # Create the body HTML.
    my $html = CGI::div({ class => 'doc' }, $page->DocPage(boxHeight => $height));
    # Output it.
    PrintLine($html);
};

if ($@) {
    # Here we have a fatal error. Save the message.
    my $errorText = "SCRIPT ERROR: $@";
    # Issue a feed event.
    Warn($errorText);
    # Output the error message.
    PrintLine CGI::pre($errorText);
}
# Close the page.
PrintLine CGI::end_html();

1;
