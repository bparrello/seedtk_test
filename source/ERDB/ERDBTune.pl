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
use Tracer;
use ERDB;

=head1 ERDBTune Script

=head2 Introduction

This script performs general utility operations on ERDB databases.

=head2 Positional Parameters

=over 4

=item dbname

Name of the database to process

=back

=head2 Command-Line Options

=over 4

=item trace

Specifies the tracing level. The higher the tracing level, the more messages
will appear in the trace log. Use E to specify emergency tracing.

=item analyze

If specified, the database tables will be vacuum analyzed to improve
performance.

=item missing

If specified, missing database tables will be created.

=item user

Name suffix to be used for log files. If omitted, the PID is used.

=item sql

If specified, turns on tracing of SQL activity.

=item background

Save the standard and error output to files. The files will be created
in the FIG temporary directory and will be named C<err>I<User>C<.log> and
C<out>I<User>C<.log>, respectively, where I<User> is the value of the
B<user> option above.

=item help

Display this command's parameters and options.

=item warn

Create an event in the RSS feed when an error occurs.

=item phone

Phone number to message when the script is complete.

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDB DBKernel) ],
                                           {
                                              trace => ["", "tracing level"],
                                              analyze => ["", "vacuum analyze the database tables"],
                                              missing => ["", "create missing tables"],
                                              phone => ["", "phone number (international format) to call when load finishes"]
                                           },
                                           "<dbname>",
                                           @ARGV);
# Set a variable to contain return type information.
my $rtype;
# Insure we catch errors.
eval {
    # Insure a database was specified.
    Confess("No database name specified.") if ! scalar(@parameters);
    # Get the target database.
    my $erdb = ERDB::GetDatabase($parameters[0]);
    my $dbh = $erdb->{_dbh};
    # Loop through the tables.
    for my $table ($erdb->GetTableNames()) {
        Trace("Processing table $table.") if T(3);
        # Process according to the options.
        if ($options->{missing}) {
            if (! $dbh->table_exists($table)) {
                Trace("Creating missing table $table.\n");
                $erdb->CreateTable($table);
            }
        }
        if ($options->{analyze}) {
            Trace("Analyzing table $table.\n");
            $erdb->Analyze($table);
        }
    }
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
    $rtype = "error";
} else {
    Trace("Script complete.") if T(2);
    $rtype = "no error";
}
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBTune terminated with $rtype.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}

1;
