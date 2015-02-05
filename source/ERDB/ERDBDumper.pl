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
use Stats;
use ERDB;
use ERDBLoadGroup;

=head1 ERDBDumper Script

=head2 Introduction

    ERDBDumper [options] <database> <group1> <group2> ...

Dump ERDB Tables

This is a simple script that will dump all the tables in one or more ERDB load
groups. The script can be used to save changes to the database content so that
copies of the database can be reloaded with the same data. Alternatively, it can
be used to back up part of a database for restoration later.

=head2 Positional Parameters

=over 4

=item database

Name of the database to be dumped (e.g. C<Sprout>, C<Sapling>).

=item group1 group2 ...

Space-delimited list of groups to dump. If C<+> is used, then all groups after
the previously-named group are included. If C<+> is used by itself, then all
groups are dumped.

=back

=head2 Command-Line Options

=over 4

=item trace

Specifies the tracing level. The higher the tracing level, the more messages
will appear in the trace log. Use E to specify emergency tracing.

=item loadDirectory

Directory in which the load files should be created. This option allows you to
dump the database to somewhere other than the default load directory.

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

=item dbName

SQL name of the target database. If not specified, the default name is used.
This option allows you to specify dumping a backup or alternate database.

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDB) ],
                                           {
                                              trace => ["2", "tracing level"],
                                              loadDirectory => ["", "alternate load directory"],
                                              dbName => ["", "if specified, the SQL name of the target database"],
                                              phone => ["", "phone number (international format) to call when load finishes"]
                                           },
                                           "<database> <group1> <group2> ...",
                                           @ARGV);
# Set a variable to contain return type information.
my $rtype;
# Create the statistics object.
my $stats = Stats->new();
my $myStartTime = time();
# Insure we catch errors.
eval {
    # Get the positional parameters.
    my ($database, @groups) = @parameters;
    # Get the database.
    Trace("Connecting to $database.") if T(2);
    my $erdb = ERDB::GetDatabase($database, undef, %$options);
    # Fix the group list.
    my @realGroups = ERDBLoadGroup::ComputeGroups($erdb, \@groups);
    # Compute the location of the load directory.
    my $loadDirectory = $options->{loadDirectory} || $erdb->LoadDirectory();
    # Loop through the groups.
    for my $group (@realGroups) {
        Trace("Processing load group $group.") if T(2);
        # Get the list of tables for this group.
        my @tables = ERDBLoadGroup::GetTables($erdb, $group);
        # Loop through them.
        for my $table (sort @tables) {
            # Dump this table.
            Trace("Dumping $table.") if T(3);
            my $count = $erdb->DumpTable($table, $loadDirectory);
            # Record its statistics.
            $stats->Add($table => $count);
            $stats->Add(records => $count);
            $stats->Add(tables => 1);
        }
        # Record this group.
        $stats->Add(groups => 1);
    }
    Trace("All groups processed.") if T(2);
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
    $rtype = "error";
} else {
    Trace("Script complete.") if T(2);
    $rtype = "no error";
}
# Display the run statistics.
$stats->Add(duration => (time() - $myStartTime));
Trace("Statistics for this run:\n" . $stats->Show()) if T(2);
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBDumper terminated with $rtype.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}

1;
