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
    use Tracer;

=head1 ERDB Relationship Integrity Check

    ERDBFixRels [options] dbName rel1 rel2 ...

This script analyzes relationships in an ERDB and deletes instances that
link to entities that do not exist.

The positional parameters are the database name followed by the relationship names.

The command-line parameters are as follows.

=over 4

=item trace

Specifies the tracing level. The higher the tracing level, the more messages
will appear in the trace log. Use E to specify emergency tracing.

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

=item DBD

Fully-qualified name of the DBD file. This option allows the use of an alternate
DBD during load so that access to the database by other processes is not
compromised.

=item dbName

SQL name of the target database. If not specified, the default name is used.
This option allows you to specify a backup or alternate database that can
be loaded without compromising the main database.

=item dbhost

Name of the MySQL database host. If not specified, the default host is used.
This option is required when the default host is restricted to read-only
database access.

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDB Stats) ],
                                           {
                                              dbName => ["", "if specified, the SQL name of the target database"],
                                              dbhost => ["", "if specified, the name of the target database"],
                                              trace => ["2", "tracing level"],
                                              DBD => ["", "if specified, the name of a DBD file in the FIG directory"],
                                           },
                                           "<database> <rel1> <rel2> ...",
                                           @ARGV);
# Get the parameters.
my ($database, @rels) = @parameters;
# Connect to the database and get its load directory.
my $erdb = ERDB::GetDatabase($database, undef, %$options);
# Create the statistics object.
my $stats = Stats->new();
# Loop through the list of relationships.
for my $rel (@rels) {
    Trace("Processing $rel.") if T(2);
    my $subStats = $erdb->FixRelationship($rel);
    Trace("Statistics for $rel:\n" . $subStats->Show()) if T(2);
    $stats->Accumulate($subStats);
}
# Denote we're done.
Trace("All done.\n" . $stats->Show()) if T(2);
