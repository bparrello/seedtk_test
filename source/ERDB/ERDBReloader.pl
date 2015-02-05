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
use ERDBLoadGroup;
use ERDBGenerate;
use ERDBExtras;
use Stats;
use Time::HiRes;


=head1 ERDBReloader Script

    ERDBReloader [options] <database> <table1> <table2> ...

ERDB Database Load Finisher

=head2 Introduction

This script loads a one or more individual tables from their load files in
the load directory.

Unlike L<ERDBGenerator.pl> and L<ERDBLoader.pl>, which operate on table
groups, this script operates on individual tables. The theory is that you
use this method to do simple repair operations instead of massive reloads.

=head2 Positional Parameters

=over 4

=item database

Name of the ERDB database. This should be the class name for the subclass used
to access the database.

=back

=head2 Command-Line Options

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

=item phone

Phone number to message when the script is complete.

=item loadDirectory

Directory containing the load files. This option allows you to request that
load files from another version of the NMPDR be used, which is useful when
creating a new NMPDR: we can yank in the data from the previous database while
waiting for the new load files to be generated.

=item dbName

SQL name of the target database. If not specified, the default name is used.
This option allows you to specify a backup or alternate database that can
be loaded without compromising the main database.

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDB Stats) ],
                                           {
                                              dbName => ["", "if specified, the SQL name of the target database"],
                                              trace => ["2", "tracing level"],
                                              phone => ["", "phone number (international format) to call when load finishes"],
                                              loadDirectory => ["", "if specified, an alternate directory containing the load files"],
                                           },
                                           "<database> <table1> <table2> ...",
                                           @ARGV);
# Set a variable to contain return type information.
my $rtype;
# Insure we catch errors.
eval {
    # Get the parameters.
    my ($database, @tables) = @parameters;
    # Connect to the database and get its load directory.
    my $erdb = ERDB::GetDatabase($database, undef, %$options);
    # Get the load directory for this database.
    my $directory = $options->{loadDirectory} || $erdb->LoadDirectory();
    # Create a statistics object to track our progress.
    my $stats = Stats->new();
    # Start a timer.
    my $totalStart = time();
    # Loop through the tables.
    for my $table (@tables) {
        # Compute the load file name.
        my $fileName = ERDBGenerate::CreateFileName($table, undef, 'data', $directory);
        # Do the actual load.
        my $newStats = $erdb->LoadTable($fileName, $table, truncate => 1, failOnError => 1);
        $stats->Accumulate($newStats);
        Trace("$fileName loaded into $table.") if T(3);
    }
    # Compute the total time.
    $stats->Add('total-time' => (time() - $totalStart));
    # Display the statistics from this run.
    Trace("Statistics for reload:\n" . $stats->Show()) if T(2);
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
} else {
    Trace("Script complete.") if T(2);
}
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBReloader completed.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}


1;