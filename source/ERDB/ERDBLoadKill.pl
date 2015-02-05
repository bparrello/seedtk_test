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

=head1 ERDBLoadKill Script

    ERDBLoadKill [options] 

ERDB Load Killer

=head2 Introduction

Tell any active load processes to terminate at the end of the current operation.
This script creates a special marker file in the load directory. When
load-related programs see the file, they stop.

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

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDBLoadGroup ERDB ERDBGenerator) ],
                                           {
                                              trace => ["2", "tracing level"],
                                              forked => [1, "do not erase the trace file"],
                                              phone => ["", "phone number (international format) to call when load finishes"]
                                           },
                                           "",
                                           @ARGV);
# Set a variable to contain return type information.
my $rtype;
# Insure we catch errors.
eval {
    # Get the database name.
    my $dbName = $parameters[0];
    # Complain if we don't have one.
    Confess("No database name specified.") if ! defined $dbName;
    # Get the database object.
    my $erdb = ERDB::GetDatabase($dbName);
    # Get the name of the load directory for this database.
    my $directory = $erdb->LoadDirectory();
    # Compute the kill file name.
    my $fileName = ERDBLoadGroup::KillFileName($erdb, $directory);
    # Create the kill file.
    my $oh = Open(undef, ">$fileName");
    print $oh "Kill request made by process $$ and user $<.\n";
    close $oh;
    Trace("Kill file $fileName created.") if T(2);
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
    $rtype = "error";
} else {
    Trace("Script complete.") if T(2);
    $rtype = "no error";
}
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBLoadKill terminated with $rtype.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}

1;
