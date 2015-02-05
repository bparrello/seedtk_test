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


=head1 ERDBLoader Script

    ERDBLoader [options] <database> <group1> <group2> ...

ERDB Database Load Finisher

=head2 Introduction

This script finishes the database load process begun by L<ERDBGenerator.pl>.

L<ERDBGenerator.pl> divides the source data into sections, and generates a
partial load file for each section of each table. To finish the load process, we
need to combine the partial files into single files and load the resulting
single files into the database tables.

Like L<ERDBGenerator.pl>, this script acts on load groups-- sets of related
tables that are loaded at the same time. For each table in a named group that
does not exist in the database, the script first attempts to find a complete set
of section files that it will collate into a data file. If there are no sections,
then it will look for a data file that is already collated. Once the collated
section files for a load group are all verified, they are loaded into the database.

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

=item keepSections

If specified, section files (the fragments of data load files created by
L<ERDBGenerator.pl>, will not be deleted after they are collated.

=item warn

Create an event in the RSS feed when an error occurs.

=item phone

Phone number to message when the script is complete.

=item DBD

Fully-qualified name of the DBD file. This option allows the use of an alternate
DBD during load so that access to the database by other processes is not
compromised.

=item loadDirectory

Directoty containing the load files. This option allows you to request that
load files from another version of the NMPDR be used, which is useful when
creating a new NMPDR: we can yank in the data from the previous database while
waiting for the new load files to be generated.

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
my ($options, @parameters) = StandardSetup([qw(ERDBLoadGroup ERDB Stats) ],
                                           {
                                              dbName => ["", "if specified, the SQL name of the target database"],
                                              dbhost => ["", "if specified, the name of the target database"],
                                              trace => ["2", "tracing level"],
                                              keepSections => ["", "if specified, section files will not be deleted after being collated"],
                                              phone => ["", "phone number (international format) to call when load finishes"],
                                              DBD => ["", "if specified, the name of a DBD file in the FIG directory"],
                                              loadDirectory => ["", "if specified, an alternate directory containing the load files"],
                                           },
                                           "<database> <group1> <group2> ...",
                                           @ARGV);
# Set a variable to contain return type information.
my $rtype;
# Insure we catch errors.
eval {
    # Get the parameters.
    my ($database, @groups) = @parameters;
    # Connect to the database and get its load directory.
    my $erdb = ERDB::GetDatabase($database, undef, %$options, externalDBD => 1);
    # Fix the group list.
    my @realGroups = ERDBLoadGroup::ComputeGroups($erdb, \@groups);
    # Get the source object and load directory for this database.
    my $source = $erdb->GetSourceObject();
    my $directory = $options->{loadDirectory} || $erdb->LoadDirectory();
    # Get the list of sections.
    my @sectionList = $erdb->SectionList($source);
    # Create a statistics object to track our progress.
    my $stats = Stats->new();
    # We make one pass to assemble all the tables in all the groups, and
    # then another to do the actual loads. The groups that are ready to load
    # in the second pass will go in this list.
    my @goodGroups;
    # Start a timer.
    my $totalStart = time();
    # Loop through the groups.
    for my $group (@realGroups) {
        # Get the list of tables for this group.
        my @tableList = ERDBLoadGroup::GetTables($erdb, $group);
        # We need to insure there is a data file for every table. If we fail to find one,
        # we set the following error flag, which prevents us from loading the database.
        my $missingTable = 0;
        # Loop through the tables in this group.
        for my $table (@tableList) {
            Trace("Processing table $table for assembly.") if T(2);
            # Get the section file names.
            my @sectionFiles =
                map { ERDBGenerate::CreateFileName($table, $_, 'data', $directory) } @sectionList;
            # Get the data file name.
            my $dataFile = ERDBGenerate::CreateFileName($table, undef, 'data', $directory);
            # Do we have it?
            my $haveFile = -f $dataFile;
            # See if we can build it. Verify that we have all the sections.
            my @missingFiles = grep { ! -f $_ } @sectionFiles;
            # Did we find everything?
            if (scalar(@missingFiles) && ! $haveFile) {
                # No, and there's no main file! Denote that we have a missing table.
                $missingTable++;
                $stats->Add('tables-skipped' => 1);
                # Tell the user about all the missing files.
                for my $missingFile (@missingFiles) {
                    $stats->Add('sections-missing' => 1);
                    $stats->AddMessage("Data file $missingFile not found for table $table.");
                }
            } elsif (! scalar @missingFiles) {
                # We have all the sections. Try to assemble them into a data file.
                my $sortStart = time();
                my $sortCommand = $erdb->SortNeeded($table) . " >$dataFile";
                Trace("Sort command: $sortCommand") if T(3);
                # Pipe to the sort command. Note that we turn on autoflush
                # so there's no buffering.
                my $oh = Open(undef, "| $sortCommand");
                select $oh; $| = 1; select STDOUT;
                # Loop through the sections.
                for my $sectionFile (@sectionFiles) {
                    Trace("Collating $sectionFile.") if T(3);
                    $stats->Add("$table-sections" => 1);
                    # Loop through the section file.
                    my $ih = Open(undef, "<$sectionFile");
                    while (defined (my $line = <$ih>)) {
                        print $oh $line;
                        $stats->Add("$table-collations" => 1);
                    }
                }
                # Finish the sort step.
                Trace("Finishing collate for $table.") if T(2);
                close $oh;
                $stats->Add('tables-collated' => 1);
                $stats->Add('collate-time' => time() - $sortStart);
                # Now that we know we have a full data file, we can delete the
                # section files to make room in the data directory. The user can
                # turn this behavior off with the keepSections option.
                if (! $options->{keepSections}) {
                    for my $sectionFile (@sectionFiles) {
                        if (-e $sectionFile) {
                            unlink $sectionFile;
                            $stats->Add('files-deleted' => 1);
                        }
                    }
                    Trace("Section files for $table deleted.") if T(3);
                }
            } else {
                # We have a data file and no sections, so we use the data file.
                $stats->Add('tables-found' => 1);
            }
        }
        # Were any tables missing?
        if ($missingTable) {
            # Yes, skip this group.
            $stats->Add('groups-skipped' => 1);
            Trace("Skipping $group group: $missingTable missing tables.") if T(2);
        } else {
            # No! File this group for processing in the second pass.
            push @goodGroups, $group;
        }
    }
    # Now we loop through the good groups, doing the actual loads.
    for my $group (@goodGroups) {
        # Get a group object.
        my $groupData = $erdb->Loader($group);
        # Do the post-processing.
        my $postStats = $groupData->PostProcess();
        # Determine what happened.
        if (! defined $postStats) {
            Trace("Post-processing not required for $group.") if T(3);
        } else {
            $stats->Accumulate($postStats);
            $stats->Add('post-processing' => 1);
        }
        # Process this group's files.
        Trace("Loading group $group into database.") if T(2);
        # Get the list of tables.
        my @tableList = $groupData->GetTables();
        # Start a timer.
        my $loadStart = time();
        for my $table (@tableList) {
            # Compute the load file name.
            my $fileName = ERDBGenerate::CreateFileName($table, undef, 'data', $directory);
            # Do the actual load.
            my $newStats = $erdb->LoadTable($fileName, $table, truncate => 1, failOnError => 1);
            $stats->Accumulate($newStats);
            Trace("$fileName loaded into $table.") if T(3);
        }
        $stats->Add("groups-loaded" => 1);
        $stats->Add('load-time' => (time() - $loadStart));
    }
    # Save the DBD.
    Trace("Saving DBD.") if T(2);
    $erdb->InternalizeDBD();
    $stats->Add('total-time' => time() - $totalStart);
    # Display the statistics from this run.
    Trace("Statistics for load:\n" . $stats->Show()) if T(2);
};
if ($@) {
    Trace("Script failed with error: $@") if T(0);
} else {
    Trace("Script complete.") if T(2);
}
if ($options->{phone}) {
    my $msgID = Tracer::SendSMS($options->{phone}, "ERDBLoader completed.");
    if ($msgID) {
        Trace("Phone message sent with ID $msgID.") if T(2);
    } else {
        Trace("Phone message not sent.") if T(2);
    }
}


1;