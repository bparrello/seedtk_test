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
    use Tracer;

=head1 DBD Update

    ERDBFixup [options] database

This script stores the specified database definition file in an ERDB database
and optionally fixes the tables to match the schema. This insures that the correct 
definition remains with the database no matter what happens to DBD on disk.

The command-line options are given below. The positional parameter is the database
type (e.g. C<Sapling>).

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

=item fixup

If specified, tables in the database not found in the DBD will be deleted, and
tables missing from the database will be created. Tables that have changed and
are empty will be dropped and re-created. Tables that have data in them will
be displayed without being updated.

=back

=cut

# Connect to the database.
# Get the command-line options and parameters.
my ($options, @parameters) = StandardSetup([qw(ERDB Stats) ],
                                           {
                                              fixup => ["", "if specified, tables will be fixed as much as possible to match the schema"],
                                              dbName => ["", "if specified, the SQL name of the target database"],
                                              dbhost => ["", "if specified, the name of the target database"],
                                              port => ["", "if specified, the port for connecting to the database"],                                             trace => ["3", "tracing level"],
                                              DBD => ["", "if specified, the name of a DBD file in the FIG directory"],
                                           },
                                           "<database> ...",
                                           @ARGV);
# Get the parameters.
my ($database) = @parameters;
# Connect to the database and get its load directory.
my $erdb = ERDB::GetDatabase($database, undef, %$options);
Trace("Database definition stored for $database.") if T(2);
# Store the DBD.
$erdb->InternalizeDBD();
if ($options->{fixup}) {
    # Create the statistics object.
    my $stats = Stats->new();
    Trace("Fixup requested.") if T(2);
    # Get the database handle.
    my $dbh = $erdb->{_dbh};
    # Get the relation names.
    my @relNames = sort $erdb->GetTableNames();
    # The list of changed tables will be kept in here.
    my %changed;
    # Get a list of a tables in the actual database.
    my @tablesFound = $dbh->get_tables();
    Trace(scalar(@tablesFound) . " tables found in database.") if T(2);
    # Create a hash for checking the tables against the schema. The check
    # needs to be case-insensitive.
    my %relHash = map { lc($_) => 1 } @relNames;
    # Loop through the tables in the database, looking for ones to drop.
    for my $table (@tablesFound) {
        $stats->Add(tableChecked => 1);
        if (substr($table, 0, 1) eq "_") {
            # Here we have a system table.
            $stats->Add(systemTable => 1);
        } elsif (! $relHash{lc $table}) {
            # Here the table is not in the DBD.
            Trace("Dropping $table.") if T(3);
            $dbh->drop_table(tbl => $table);
            $stats->Add(tableDropped => 1);
        } else {
            # Here we need to compare the table's real schema to the DBD.
            Trace("Analyzing $table.") if T(3);
            # This is the real scheme.
            my @cols = $dbh->table_columns($table);
            # We'll set this to TRUE if there is a difference.
            my $different;
            # Loop through the DBD schema, comparing.
            my $relation = $erdb->FindRelation($table);
            my $fields = $relation->{Fields};
            my $count = scalar(@cols);
            if (scalar(@$fields) != $count) {
                Trace("$table has a different column count.") if T(3);
                $different = 1;
            } else {
                # The column count is the same, so we do a 1-for-1 compare.
                for (my $i = 0; $i < $count && ! $different; $i++) {
                    # Get the fields at this position.
                    my $actual = $cols[$i];
                    my $schema = $fields->[$i];
                    # Compare the names and the nullabilitiy.
                    if (lc $actual->[0] ne lc ERDB::_FixName($schema->{name})) {
                        Trace("Field mismatch at position $i in $table.") if T(3);
                        $different = 1;
                    } elsif ($actual->[2] ? (! $schema->{null}) : $schema->{null}) {
                        Trace("Nullability mismatch in $actual->[0] of $table.") if T(3);
                        $different = 1;
                    } else {
                        # Here we have to compare the field types. Because of
                        # a glitch, we only look at the first word.
                        my ($schemaType) = split m/\s+/, $erdb->_TypeString($schema);
                        if (lc $schemaType ne lc $actual->[1]) {
                            Trace("Type mismatch in $actual->[0] of $table.") if T(3);
                            $different = 1;
                        }
                    }
                }
            }
            if ($different) {
                # Here we have a table mismatch.
                $stats->Add(tableMismatch => 1);
                # Check for data in the table.
                if ($erdb->IsUsed($table)) {
                    # There's data, so save it for being listed
                    # later.
                    $changed{$table} = 1;
                } else {
                    # No data, so drop it.
                    Trace("Dropping $table.") if T(3);
                    $dbh->drop_table(tbl => $table);
                    $stats->Add(tableDropped => 1);
                }
            }
        }
    }
    # Loop through the relations.
    for my $relationName (@relNames) {
        $stats->Add(relationChecked => 1);
        # Do we want to create this table?
        if (! $dbh->table_exists($relationName)) {
            $erdb->CreateTable($relationName, 1);
            Trace("$relationName created.") if T(3);
            $stats->Add(relationCreated => 1);
        } elsif ($changed{$relationName}) {
            Trace("$relationName needs to be recreated.") if T(1);
        }
    }
    # Tell the user we're done.
    Trace("Database fixup complete.\n" . $stats->Show()) if T(2);
    
}

