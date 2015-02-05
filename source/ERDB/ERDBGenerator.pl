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
use ERDBGenerate;
use ERDBLoadGroup;
use ERDBExtras;

=head1 ERDBGenerator Script

    ERDBGenerator [options] database group1 group2 ...

Generate ERDB table load files

=head2 Introduction

This script manages the generation of load files for an ERDB database. It can
either function as a worker process that reads section IDs from the standard
input and generates the load files for each, or it can function as a management
process that starts a bunch of workers and gives them work.

The positional parameters include a list of load groups to process and the name
of the database.

=head2 Positional Parameters

=over 4

=item database

Name of the ERDB database. This should be the class name for the L<ERDB>
subclass used to access the database.

=item groups

List of the table groups to load. A C<+> at the end of the list indicates that
all groups that follow the last-named group in the standard order should
be loaded. A C<+> by itself loads all groups in standard order.

=back

=head2 Command-Line Options

=over 4

=item background

Save the standard and error output to files. The files will be created
in the FIG temporary directory and will be named C<err>I<User>C<.log> and
C<out>I<User>C<.log>, respectively, where I<User> is the value of the
B<user> option above.

=item clean

Remove temporary files from the load directory. Use this option with care,
since it will crash if a worker process is still running.

=item clear

If specified, all generated files in the load directory with a C<dt>X suffix
will be erased. This restores the load directory to a pristine, pre-loading state.

=item clearGroups

If specified, all generated files related to each specified group will be
erased prior to any further processing. This is useful if a single group
needs to be reloaded and we don't want to be confused by files leftover
from previous loads.

=item forked

If specified, then the trace file will not be erased during initialization.
This prevents the worker processes from stepping on each other's trace output.

=item help

Display this command's parameters and options.

=item maxErrors

If specified, then this prcoess will terminate after the specified number of
section load errors; otherwise, the process will keep going after a section
error. A value of C<0> means the process will ignore all errors. A value of
C<1> means it will stop after the first error. The default is C<1>.

=item phone

Phone number to message when the script is complete.

=item sections

Name of a file containing a list of sections to process. If C<*> is specified (the
default), all sections are processed. This options is ignored if C<workers> is
C<0>. In that case, the list of sections is taken from the standard input. When
a file name is specified, if it is not an absolute file name, it is presumed to
be in the database's load directory.

=item sql

If specified, turns on tracing of SQL activity.

=item trace

Specifies the tracing level. The higher the tracing level, the more messages
will appear in the trace log. Use E to specify emergency tracing.

=item user

Name suffix to be used for log files. If omitted, the PID is used.

=item warn

Create an event in the RSS feed when an error occurs.

=item label

Name of this process, for display during tracing.

=item resume

If specified, load files that already exist will not be regenerated.

=item workers

If C<0>, then this is considered to be a worker process and the sections in the
standard input are processed. If C<1>, then all sections are processed without
any parallelism and the standard input is ignored. If it is any other number,
then the appropriate number of worker processes are generated and the sections
are assigned to them in a round-robin fashion.

=item memTrace

Trace memory usage at the end of each section.

=item DBD

Fully-qualified name of the DBD file. This option allows the use of an alternate
DBD during load, so that access to the database by other processes is not
compromised.

=back

=cut

# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDBLoadGroup ERDBGenerate ERDB Stats) ],
                                           {
                                              clear => ["", "if specified, the entire load directory will be cleared"],
                                              clean => ["", "if specified, temporary files in the load directory will be deleted"],
                                              clearGroups => ["", "if specified, pre-exising load files from the groups processed will be deleted"],
                                              maxErrors => ["1", "if non-zero, the maximum allowed number of section failures"],
                                              phone => ["", "phone number (international format) to call when load finishes"],
                                              trace => ["3", "tracing level"],
                                              workers => ["1", "number of worker processes"],
                                              label => ["Main", "name of this process"],
                                              resume => ["", "if specified, only groups and sections that do not already have load files will be processed"],
                                              sections => ["*", "name of a file in the database's load directory containing a list of sections to process"],
                                              DBD => ["", "if specified, the name of a DBD file in the FIG directory"],
                                              memTrace => ["", "if specified, memory usage will be traced at the end of each section"],
                                           },
                                           "<database> <group1> <group2> ...",
                                           @ARGV);
# This is a list of the options that are for manager scripts only.
my @managerOptions = qw(clear clean clearGroups sections);
# We're doing heavy pipe stuff, so we need to throw an error on a broken-pipe signal.
local $SIG{PIPE} = sub { Confess("Broken pipe.") };
# Insure we catch errors.
eval {
    # Get the parameters.
    my ($database, @groups) = @parameters;
    # Check for an alternate DBD.
    my $altDBD = $options->{DBD} || undef;
    # Connect to the database and get its load directory.
    my $erdb = ERDB::GetDatabase($database, $altDBD, externalDBD => 1);
    my $directory = $erdb->LoadDirectory();
    Trace("Load directory is $directory.") if T(3);
    my $source = $erdb->GetSourceObject();
    # Fix the group list.
    my @realGroups = ERDBLoadGroup::ComputeGroups($erdb, \@groups);
    # Are we a worker or a manager?
    if ($options->{workers} == 0) {
        # Yes, we're a worker.
        Trace("Worker process $options->{label} started.") if T(2);
        LoadFromInput(\*STDIN, $erdb, \@realGroups, $options);
    } else {
        # Here we're a manager. If the user wants us to clear the directory,
        # do that first.
        if ($options->{clear}) {
            # Count the number of files deleted.
            my $deleteCount = 0;
            # Get a list of the applicable file names.
            my @files = ERDBGenerate::GetLoadFiles($directory);
            # It's worth noting if we didn't find any.
            if (! @files) {
                Trace("Load directory is already clear.") if T(2);
            } else {
                # Delete the files we found.
                for my $file (@files) {
                    unlink "$directory/$file";
                    $deleteCount++;
                }
                Trace("$deleteCount files deleted from load directory during Clear.") if T(2);
            }
        } elsif ($options->{clearGroups}) {
            # Here the user only wants to clear the load files for the specified
            # groups. This operation requires significantly greater care. Get
            # the hash of groups to table names.
            my $groupHash = ERDBLoadGroup::GetGroupHash($erdb);
            # Get a list of the files in this directory in alphabetical order.
            my @files = ERDBGenerate::GetLoadFiles($directory);
            # Get a hash of all the tables to be deleted.
            my %tables = map { $_ => 1 } map { @{$groupHash->{$_}} } @realGroups;
            # We'll count the number of files deleted in here.
            my $deleteCount = 0;
            # Loop through all the files in the directory.
            for my $file (@files) {
                # Extract the relevant table name from the file.
                my ($table) = ERDBGenerate::ParseFileName($file);
                if ($tables{$table}) {
                    # This is one of our tables, so delete the file.
                    unlink "$directory/$file";
                    $deleteCount++;
                    Trace("$deleteCount files deleted.") if T(3) && $deleteCount % 100 == 0;
                }
            }
            Trace("$deleteCount files deleted from load directory during ClearGroups.") if T(2);
        }
        # Delete any leftover kill file if it exists.
        my $killFileName = ERDBLoadGroup::KillFileName($erdb, $directory);
        if (-f $killFileName) {
            Trace("Deleting kill file $killFileName.") if T(2);
            unlink $killFileName;
        }
        # Now we need to get our list of sections. Check to see if the user
        # supplied a section file.
        my $sectionFile = $options->{sections};
        if ($sectionFile eq "*") {
            # No, so we must create one.
            $sectionFile = "$directory/Sections$$.txt";
            Open(\*SECTIONS, ">$sectionFile");
            for my $section ($erdb->SectionList($source)) {
                print SECTIONS "$section\n";
            }
            close SECTIONS;
        } elsif ($sectionFile =~ m#^\w#) {
            # Yes, but it doesn't have a directory name, so add one.
            $sectionFile = "$directory/$sectionFile";
        }
        # Compute the options to be used for worker processes (or ourselves if
        # we're sequential).
        my %workerOptions = %{$options};
        # Get rid of the manager-only options.
        for my $optionID (@managerOptions) {
            delete $workerOptions{$optionID};
        }
        # Insure the worker knows what it is.
        $workerOptions{workers} = 0;
        $workerOptions{forked} = 1;
        $workerOptions{background} = 1;
        # Prepare to read the section file.
        my $ih = Open(undef, "<$sectionFile");
        # Are we a sequential load or a multi-worker manager?
        my $numWorkers = $options->{workers};
        if ($numWorkers == 1) {
            # We're sequential, so we do all the work ourselves.
            Trace("Sequential load started.") if T(2);
            LoadFromInput($ih, $erdb, \@realGroups, \%workerOptions);
        } else {
            # Here we need to create the workers. The following array will contain
            # a descriptor for each worker.
            my @workers = ();
            # Compute the positional parameters to use for the workers.
            my $commandParms = join(" ", $database, @realGroups);
            my $command = $0;
            # Create the workers.
            for (my $i = 0; $i < $numWorkers; $i++) {
                my $label = "$options->{label}$i";
                $workerOptions{label} = $label;
                my $commandOptions = Tracer::UnparseOptions(\%workerOptions);
                my $inFile = "$ERDBExtras::temp/Pipe-$label.tbl";
                my $oh = Open(undef, ">$inFile");
                my $command = "$command $commandOptions $commandParms <$inFile >null &";
                push @workers, { handle => $oh, label => $label, command => $command };
            }
            # Now we assign sections to the workers.
            my $w = 0;
            while (! eof $ih) {
                # Get the name of the next section.
                my $line = <$ih>;
                # Get the output handle for the next worker in rotation.
                my $wh = $workers[$w]->{handle};
                # Send this section to it.
                print $wh $line;
                Trace(Tracer::Strip($line) . " sent to $workers[$w]->{label}") if T(3);
                # Position on the next worker.
                $w = ($w + 1) % $numWorkers;
            }
            # All done, close the files.
            for my $worker (@workers) {
                close $worker->{handle};
            }
            # Now start the workers.
            for my $worker (@workers) {
                my $cmd = $worker->{command};
                Trace("Starting: $cmd") if T(3);
                system($worker->{command});
            }
        }
        Trace("Load manager completed.") if T(2);
    }
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
} else {
    Trace("Script complete.") if T(2);
}
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBGenerator has ended.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}

=head2 Internal Methods

=head3 LoadFromInput

    LoadFromInput($ih, $erdb, \@groups, \%options);

Load one or more sections of data for the specified table groups. The IDs
of the data sections will be read from the standard input. The groups
will be loaded in the order specified, once per section.

=over 4

=item ih

File handle for the input stream containing the list of sections to process.

=item erdb

Database object containing information about the tables being loaded.

=item groups

Reference to a list of the names for the load groups to process.

=item options

Reference to a hash of the options passed in from the command line.

=back

=cut

sub LoadFromInput {
    # Get the parameters.
    my ($ih, $erdb, $groups, $options) = @_;
    # We'll count our errors in here.
    my $errorCount = 0;
    my $maxErrors = $options->{maxErrors};
    # Create the master statistics object.
    my $stats = Stats->new();
    # Compute the kill file name.
    my $killFileName = ERDBLoadGroup::KillFileName($erdb, $erdb->LoadDirectory());
    my $killed = 0;
    # Slurp in the sections.
    my @sections = ();
    while (! eof $ih) {
        push @sections, Tracer::GetLine($ih);
    }
    # Loop through the groups.
    for my $group (@$groups) {
        # Create a loader for this group.
        my $loader = $erdb->Loader($group, $options);
        # Loop through the sections.
        for my $section (@sections) {
            # Only proceed if we haven't been killed.
            if (! $killed) {
                # Check for a kill file.
                if (-f $killFileName) {
                    # Found one, so kill ourselves.
                    Trace("$options->{label} terminated by kill file.") if T(2);
                    $killed = 1;
                } else {
                    # No kill file, so we process the section.
                    Trace("Processing section $section for group $group in $options->{label}.") if T(3);
                    # Memorize the current memory footprint.
                    my $memory0 = Tracer::GetMemorySize();
                    my $ok = $loader->ProcessSection($section);
                    # Do memory tracing.
                    if ($options->{memTrace}) {
                        my $memory1 = Tracer::GetMemorySize();
                        Trace("Memory usage by $options->{label} for $group $section was $memory0 to $memory1.") if T(2);
                    }
                    # Check to see if we've exceeded the maximum error count. We only care
                    # if maxErrors is nonzero.
                    if (! $ok && $maxErrors && ++$errorCount >= $maxErrors) {
                        Trace("Error limit exceeded in database loader.") if T(0);
                        $killed = 1;
                    }
                }
            }
        }
        # Display our statistics.
        Trace("Statistics for $group in $options->{label}:\n" . $loader->DisplayStats()) if T(2);
        # Add them to the master statistics.
        $loader->AccumulateStats($stats);
    }
    # Tell the user we're done.
    Trace("Processing finished for worker $options->{label}.") if T(2);
    Trace("Statistics for this worker:\n" . $stats->Show()) if T(2);
}

1;
