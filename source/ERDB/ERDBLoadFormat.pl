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
use ERDBExtras;


=head1 ERDBLoadFormat Script

    ERDBLoadFormat [options] <database>

ERDB Database Load Format Display

=head2 Introduction

This script displays in the form of a text file the information needed to
create load files for the specified ERDB database.

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

=item entities

If specified, name of a file containing a list of entities. Only tables
related to the entities will be displayed.

=back

=cut

    # Get the command-line options and parameters.
    my ($options, @parameters) = StandardSetup([qw(ERDB) ],
                                               {
                                                  dbName => ["", "if specified, the SQL name of the target database"],
                                                  dbhost => ["", "if specified, the name of the target database"],
                                                  port => ["", "if specified, the port on which to connect to the target database"],
                                                  trace => ["2-", "tracing level"],
                                                  DBD => ["", "if specified, the name of a DBD file in the FIG directory"],
                                                  entities => ["", "if specified, the name of a file containing the entities of interest"]
                                               },
                                               "<database>",
                                               @ARGV);
    # Connect to the database.
    my $erdb = ERDB::GetDatabase($parameters[0], undef, %$options, externalDBD => 1, offline => 1);
    # Get the hash of entities.
    my $entityHash = $erdb->GetObjectsTable('entity');
    # Get the list of entities of interest.
    my %entities;
    if ($options->{entities}) {
        %entities = map { $_ => $entityHash->{$_} } Tracer::GetFile($options->{entities});
    } else {
        %entities = %$entityHash;
    }
    # Loop through the list of entities.
    for my $entity (sort keys %entities) {
        # Display the entity description.
        DisplayObject($entity, \%entities);
        # Space before the next entity.
        print "\n";
    }
    # Loop through the list of relationships.
    my $relationshipHash = $erdb->GetObjectsTable('relationship');
    for my $relationship (sort keys %$relationshipHash) {
        # Get the FROM and TO entites.
        my $from = $relationshipHash->{$relationship}->{from};
        my $to = $relationshipHash->{$relationship}->{to};
        # Only display this relationship if both ends are in our
        # list of entities.
        if (exists $entities{$from} && exists $entities{$to}) {
            DisplayObject($relationship, $relationshipHash);
            # Space before the next relationship.
            print "\n";
        }
    }

# Display the data about an object and its relations.
sub DisplayObject {
    my ($object, $objectHash) = @_;
    FormatNotes($object, $objectHash->{$object}->{Notes}->{content});
    print "\n";
    # Loop through its relations.
    my $relHash = $objectHash->{$object}->{Relations};
    for my $table (sort keys %$relHash) {
        print "    Table: $table\n";
        # Get this table's fields.
        my $relData = $relHash->{$table};
        # Loop through them.
        for my $fieldData (@{$relData->{Fields}}) {
            # Get the field's name.
            my $name = $fieldData->{name};
            # Get the field's type.
            my $type = $fieldData->{type};
            # Display this field's information.
            FormatNotes("        $name ($type)", $fieldData->{Notes}->{content});
        }
        # Space before the next table.
        print "\n";
    }
}

# Display an object with its formatted notes.
sub FormatNotes {
    my ($heading, $notes) = @_;
    # Create the display prefix from the heading.
    my $prefix = "$heading:";
    # Compute the length of the prefix.
    my $length = length $prefix;
    # Create the prefix for secondary lines.
    my $spacer = " " x $length;
    # Delete all the markers from the notes.
    $notes =~ s/\[[^\]]+\]//g;
    # Break the notes into words.
    my @words = split /(?:\s|\n)+/, $notes;
    # Form the words into lines.
    my @line = $prefix;
    my $lineLength = $length;
    for my $word (@words) {
        push @line, $word;
        $lineLength += 1 + length $word;
        if ($lineLength >= 75) {
            print join(" ", @line) . "\n";
            @line = ($spacer);
            $lineLength = $length;
        }
    }
    if (scalar @line > 1) {
        print join(" ", @line) . "\n";
    }
}