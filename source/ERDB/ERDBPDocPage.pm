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

package ERDBPDocPage;

    use strict;
    use Tracer;
    use ERDB;
    use CGI;
    use ERDBExtras;

=head1 ERDB Pseudo-Documentation Page

=head2 Introduction

This module is used to generate a small pseudo-documentation page for ERDB. The
page includes a dropdown box that allows you to select an object in the database
and see a summary of its fields and relationships.

Each object in the database will have its documentation wrapped in a DIV block
computable from the object name. All the links will call a javascript method to
reveal the appropriate block. A stack of the viewed blocks is kept in the
javascript data structures so the user can go back. Each object in the database
has a name that is unique among all the object types, so the name is sufficient
to identify the DIV block.

The fields in this object are as follows.

=over 4

=item erdb

L<ERDB> object describing the database.

=item idString

A unique ID string used to prefix the names of all the DIV blocks
generated by this object.

=item javaThing

The name of the JavaScript variable that will contain the current state
of the documentation HTML.

=item selectBox

The ID of the select box that controls this widget.

=back

=head3 Useful Constants

=over 4

=item ARITY_FROM

Maps each arity to its description when seen in the forward direction.

=item ARITY_TO

Maps each arity to its description when seen in the reverse direction.

=back

=cut

use constant ARITY_FROM => { '1M' => 'one-to-many', 'MM' => 'many-to-many' };
use constant ARITY_TO   => { '1M' => 'many-to-one', 'MM' => 'many-to-many' };

=head3 new

    my $html = ERDBPDocPage->new(%options);

Construct a new ERDBPDocPage object. The following options are supported.

=over 4

=item name

Name of the relevant ERDB database.

=item dbObject

L<ERDB> object for the databasse. If this option is specified, it
overrides =name=.

=item idString

A unique ID string used to prefix the names of all the DIV blocks
generated by this object. If none is provided, an empty string is
used. If provided, the string must consist entirely of letters, digits,
and underscores, because it's used in javascript variable names.

=back

=cut

sub new {
    # Get the parameters.
    my ($class, %options) = @_;
    # We'll store the ERDB object we want in here.
    my $erdb;
    # Get the options.
    my $name = $options{name};
    my $dbObject = $options{dbObject};
    my $idString = $options{idString} || '';
    # Attach the desired ERDB object.
    if ($dbObject) {
        # Here we have a connected object.
        $erdb = $dbObject;
    } elsif ($name) {
        # Here we need to create the database object from the name.
        $erdb = ERDB::GetDatabase($name);
    }
    # Create the ERDBPDocPage object.
    my $retVal = {
                    erdb => $erdb,
                    idString => $idString,
                    javaThing => "status_erdb_$idString",
                    selectBox => "select_box_$idString",
                 };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}

=head2 Public Methods

=head3 DocPage

    my $docPage = $html->DocPage(%options);

Create a documentation widget for the current ERDB database. The documentation
widget features a multi-level menu on the left. When the user selects an object,
that object's documentation block is made visible on the right. The page containing
the document needs to have C<ERDB.js> included for scripting and C<ERDB.css>
for styles. The parameter is a hash of options. The permissible options are given
below.

=over 4

=item boxHeight

The height for the display area, in pixels. The default is 450.

=item padding

The padding to use around the display elements, in pixels. The default is 5.

=item buttonWidth

The width of the navigation buttons, in pixels. The default is 50.

=item selectWidth

The width of the selection area, in pixels. The default is 150.

=item displayWidth

The width of the display area, in pixels. The default is the diagram
width (if any) or 600 if there is no diagram.

=item

=back

=cut

sub DocPage {
    # Get the parameters.
    my ($self, %options) = @_;
    # Extract the options.
    my $boxHeight = $options{boxHeight} || 450;
    my $padding = $options{padding} || 5;
    my $buttonWidth = $options{buttonWidth} || 50;
    my $selectWidth = $options{selectWidth} || 150;
    # Compute the width for the popup menu thing.
    my $menuWidth = $selectWidth - 2 * $padding;
    my $menuHeight = $boxHeight;
    # Get the ERDB object.
    my $erdb = $self->{erdb};
    # Get the diagram options (if any).
    my $diagramData = $erdb->GetDiagramOptions();
    # Compute the width for the display area.
    my $displayWidth = $options{displayWidth};
    # If there is no explicit width, we need to apply a default width.
    if (! $displayWidth) {
        # Check for a diagram. If we have one, its width takes precedence.
        if (defined $diagramData) {
            $displayWidth = $diagramData->{width};
        }
        # If there's no diagram, or the diagram does not have a width,
        # we apply a default.
        if (! defined $displayWidth) {
            $displayWidth = 600;
        }
    }
    # Add room for padding.
    $displayWidth += 4 * $padding;
    # Convert all the numbers to measurements.
    for my $measurement (qw(boxHeight padding buttonWidth selectWidth
                            menuHeight menuWidth displayWidth)) {
        eval("\$$measurement .= 'px'");
    }
    # We'll format our HTML in here.
    my @lines;
    # First and foremost, we need a list of the object types in documentation
    # order.
    my @types = qw(entity relationship shape);
    # We need a list of the DIV block names, a list of the DIV blocks themselves,
    # and a list of object names for each object type.
    my (@divBlocks, @divNames);
    my %optGroups = map { $_ => [] } @types;
    # Loop through the three object types.
    for my $type (@types) {
        # Get the option group list for this type.
        my $optGroup = $optGroups{$type};
        # Get the table of objects of this type.
        my $groupObjectsTable = $erdb->GetObjectsTable($type);
        # Loop through them in lexical order.
        for my $name (sort keys %$groupObjectsTable) {
            # Put this object in the current option group.
            push @$optGroup, $name;
            # Put its DIV identifier in the name list.
            my $divID = $self->_DivID($name);
            push @divNames, $divID;
            # Generate its block.
            my $divBlockHtml = $self->DocObject($type => $name,
                                                $groupObjectsTable->{$name});
            my $divBlock = CGI::div({ id => $divID,
                                      style => "display: none;" },
                                      $divBlockHtml);
            # Save the block with the DIV ID.
            push @divBlocks, $divBlock;
        }
    }
    # Now we set up the diagram. The next two values are used to determine
    # the functionality and name of the reset button. If there's no diagram,
    # the button clears the display. If there is, the button shows the diagram.
    my $diagramName = '';
    my $clearButton = 'CLEAR';
    # A diagram is only going to be applicable if we have diagram options.
    if ($diagramData) {
        # Here we can do a diagram. Create a DIV for it.
        $diagramName = 'DBDiagram';
        my $divID = $self->_DivID($diagramName);
        push @divNames, $divID;
        # Generate its block.
        my $diagramHTML = $self->BuildDiagram($diagramData);
        my $divBlock = CGI::div({ id => $divID,
                                  style => "display: block;" },
                                  $diagramHTML);
        # Change the name of the reset button.
        $clearButton = 'IMAGE';
        # Save the block with the DIV ID.
        push @divBlocks, $divBlock;
    }
    # Now we create the script to set this all up.
    my $initCall = "new ErdbStatusThing(\"$self->{selectBox}\", \"" .
                                        join(" ", @divNames) . "\")";
    push @lines, "<script type=\"text/javascript\">",
                 "   var $self->{javaThing} = $initCall;",
                 "</script>";
    # Next we create the menu box. First, we need a list of the nonempty
    # option groups.
    my @optGroupList;
    for my $type (@types) {
        my $thisGroup = $optGroups{$type};
        if (scalar @$thisGroup) {
            push @optGroupList, CGI::optgroup(-name => ERDB::Plurals($type),
                                              -values => $thisGroup);
        }
    }
    # This is the event string we want when the menu box value changes.
    my $event = "ShowBlockReset($self->{javaThing}, '$self->{idString}' + this.value)";
    # Note that the size parameter doesn't really matter. It has to be something
    # greater than 1, but the real size is determined by the style.
    my $menuBox = CGI::popup_menu(-id => $self->{selectBox},
                                  -values => \@optGroupList, -size => 99,
                                  -style => "width: $menuWidth; height: $menuHeight;",
                                  -onChange => $event);
    # Next we have the DIV blocks themselves.
    my $divBlocks = join("\n", @divBlocks);
    # Now we have the buttons.
    my $buttonStyle = "width: $buttonWidth; text-align: center;";
    my @buttons = (CGI::button(-value => 'BACK', -style => $buttonStyle,
                               -class => 'button',
                               -onClick => "ShowPrevious($self->{javaThing})"),
                   CGI::button(-value => $clearButton, -style => $buttonStyle,
                               -class => 'button',
                               -onClick => "ShowBlockReset($self->{javaThing}, '$diagramName')"),
                  );
    # Create the style for the documentation display area.
    my $divStyle = "width: $displayWidth; overflow-x: display; " .
                    "overflow-y: auto; height: $boxHeight";
    # Assemble the menu and the div blocks.
    push @lines, CGI::table({ border => 0, valign => 'top' },
                    CGI::Tr(CGI::td(join(" ", @buttons))),
                    CGI::Tr(
                        CGI::td({ style => "padding: $padding; width: $selectWidth" },
                                $menuBox),
                        CGI::td({ style => "padding: $padding"},
                                CGI::div({ style => $divStyle }, $divBlocks)),
                    ));
    # Return the result.
    my $retVal = join("\n", @lines, "");
    return $retVal;
}


=head3 DocObject

    my $html = $html->DocObject($type => $name, $metadata);

Create a documentation block for the specified entity, relationship, or
shape. The documentation block will contain a title, but will not be
wrapped in a DIV block or anything fancy.

=over 4

=item type

Type of object: C<entity>, C<relationship>, or C<shape>. The types are
case-insensitive, and plurals work.

=item name

Name of the entity, relationship, or shape.

=item metadata

L<ERDB> metadata object describing the entity, relationship, or shape.

=item RETURN

Returns a documentation block for the specified object.

=back

=cut

sub DocObject {
    # Get the parameters.
    my ($self, $type, $name, $metadata) = @_;
    # Declare the return variable.
    my $retVal;
    # Process according to the type of thing.
    if ($type =~ /^entit(y|ies)/i) {
        $retVal = $self->DocEntity($name => $metadata);
    } elsif ($type =~ /^relationship/i) {
        $retVal = $self->DocRelationship($name => $metadata);
    } elsif ($type =~ /^shape/i) {
        $retVal = $self->DocShape($name => $metadata);
    } else {
        Confess("Invalid object type \"$type\" in documentation handler.");
    }
    # Return the result.
    return $retVal;
}

=head3 DocEntity

    my $htmlBlock = $html->DocEntity($name => $metadata);

Return the documentation block for the specified entity.

=over 4

=item name

Name of the entity whose documentation block is desired.

=item metadata

L<ERDB> metatada structure for the specified entity.

=item RETURN

Returns a documentation block for the specified entity.

=back

=cut

sub DocEntity {
    # Get the parameters.
    my ($self, $name, $metadata) = @_;
    # Get the database object.
    my $erdb = $self->{erdb};
    # We'll build the documentation block in here.
    my @lines;
    # Start with the heading.
    push @lines, $self->ObjectHeading(entity => $name);
    # Create the notes and asides.
    push @lines, ERDB::ObjectNotes($metadata, $self);
    # Get the connecting relationships.
    my ($from, $to) = $erdb->GetConnectingRelationshipData($name);
    # We'll accumulate relationship sentences in here.
    my @relationships;
    # First we do the forward relationships.
    for my $fromRel (sort keys %$from) {
        my $relData = $from->{$fromRel};
        my $line = join(" ", $name, CGI::strong($self->Linked($fromRel)),
                        $self->Linked($relData->{to}),
                        "(" . ARITY_FROM->{$relData->{arity}} . ")");
        push @relationships, $line;
    }
    # Now the backward relationships.
    for my $toRel (sort keys %$to) {
        my $relData = $to->{$toRel};
        # This is tricky, because we want to use the converse name,
        # and we may not have one. We'll assemble our components in here.
        my @words;
        # Get the entity on the other side.
        my $from = $self->Linked($relData->{from});
        # Create the sentence.
        if ($relData->{converse}) {
            push @words, $name,
                CGI::strong($self->Linked($toRel, $relData->{converse})),
                $from, "(" . ARITY_TO->{$relData->{arity}} . ")";
        } else {
            push @words, $from, CGI::strong($self->Linked($toRel)),
                $name, "(" . ARITY_FROM->{$relData->{arity}} .")";
        }
        # Join the pieces together and put them in the list.
        push @relationships, join(" ", @words);
    }
    # If there are any relationships at all, we render them as a bullet list.
    if (scalar @relationships) {
        # Create a heading.
        push @lines, $self->Heading(4, "Relationships");
        # Convert the relationship sentences to list items.
        my @sentences = map { CGI::li($_) } @relationships;
        # Form them into a bullet list if there's only one, a numbered list
        # otherwise.
        if (scalar @relationships == 1) {
            push @lines, CGI::start_ul(), @sentences, CGI::end_ul();
        } else {
            push @lines, CGI::start_ol(), @sentences, CGI::end_ol();
        }
    }
    # Display the fields.
    push @lines, $self->DocFields($name, $metadata);
    # Display the indexes.
    push @lines, $self->DocIndexes($name, $metadata);
    # Return the result.
    my $retVal = join("\n", @lines);
    return $retVal;
}

=head3 DocRelationship

    my $htmlBlock = $html->DocRelationship($name => $metadata);

Create a documentation block for the specified relationship. The
documentation block will contain a title, but will not be wrapped in a
DIV block or anything fancy.

=over 4

=item name

Name of the relationship to document.

=item metadata

L<ERDB> metadata structure for the relationship.

=item RETURN

Returns an HTML string describing the relationship.

=back

=cut

sub DocRelationship {
    # Get the parametrs.
    my ($self, $name, $metadata) = @_;
    # We'll build the documentation block in here.
    my @lines;
    # Start with the heading.
    push @lines, $self->ObjectHeading(relationship => $name);
    # Create the notes and asides.
    push @lines, ERDB::ObjectNotes($metadata, $self);
    # Create linked-up versions of the entity names.
    my $fromEntity = $self->Linked($metadata->{from});
    my $toEntity = $self->Linked($metadata->{to});
    # Get the arities.
    my $fromArity = ARITY_FROM->{$metadata->{arity}};
    my $toArity = ARITY_TO->{$metadata->{arity}};
    # Create the from-sentence.
    my $fromLine = join(" ", $fromEntity, $name, $toEntity,
                        "($fromArity)");
    # Determine whether or not we have a converse.
    my $converseName = $metadata->{converse} || "[$name]";
    # Create the to-sentence.
    my $toLine = join(" ", $toEntity, $converseName, $fromEntity,
                      "($toArity)");
    # Generate the relationship sentences.
    push @lines, CGI::ul(CGI::li([$fromLine, $toLine]));
    # Display the fields.
    push @lines, $self->DocFields($name, $metadata);
    # Display the indexes.
    push @lines, $self->DocIndexes($name, $metadata);
    # Return the result.
    my $retVal = join("\n", @lines);
    return $retVal;
}

=head3 DocShape

    my @lines = $html->DocShape($name => $metadata);

Create a documentation block for the specified shape. The documentation
block will contain a title, but will not be wrapped in a DIV block or
anything fancy.

=over 4

=item name

Name of the shape to document.

=item metadata

L<ERDB> metadata structure for the shape.

=item RETURN

Returns an HTML string describing the shape.

=back

=cut

sub DocShape {
    # Get the parameters.
    my ($self, $name, $metadata) = @_;
    # We'll build the documentation block in here.
    my @lines;
    # Start with the heading.
    push @lines, $self->ObjectHeading(shape => $name);
    # Create the notes and asides.
    push @lines, ERDB::ObjectNotes($metadata, $self);
    # Return the result.
    my $retVal = join("\n", @lines);
    return $retVal;
}

=head3 DocIndexes

    my @lines = $html->DocIndexes($name, $metadata);

Display the indexes associated with the specified object.

=over 4

=item name

Name of the entity or relationship whose indexes are to be documented.

=item metadata

L<ERDB> metadata structure for the specified entity or relationship.

=item RETURN

Returns a list of HTML lines that describe the indexes of the specified
object.

=back

=cut

sub DocIndexes {
    # Get the parameters.
    my ($self, $name, $metadata) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the list of relations for this object.
    my $relations = $metadata->{Relations};
    # Create a heading for the index table. There is always at least
    # one index, so the heading will never be empty.
    push @retVal, $self->Heading(4, "$name Indexes");
    # Compute the column headers.
    my @headers = (text => 'Table', text => 'Name', text => 'Type',
                   text => 'Fields', text => 'Notes');
    # We'll put the table rows in here.
    my @rows;
    # Loop through the relations.
    for my $relation (sort keys %$relations) {
        # Get this relation's index list.
        my $indexes = $relations->{$relation}{Indexes};
        # Loop through the indexes. For each index, we generate a table row.
        for my $index (sort keys %$indexes) {
            # Get this index's descriptor.
            my $indexData = $indexes->{$index};
            # Compute its notes.
            my $notes = join("\n", ERDB::ObjectNotes($indexData, $self));
            # Compute its type.
            my $type = ($indexData->{unique} ? 'unique' : '');
            # Compute its field list.
            my $fields = join(", ", @{$indexData->{IndexFields}});
            # Only list the index if it is noteworthy.
            if ($fields ne 'id' || $notes) {
                # Create the table row.
                push @rows, [$relation, $index, $type, $fields, $notes];
            }
        }
    }
    # Emit the table.
    push @retVal, FancyTable(\@headers, @rows);
    # Return the result.
    return @retVal;
}

=head3 DocFields

    my @lines = $html->DocFields($name, $metadata);

Display the table of fields for the specified object.

=over 4

=item name

Name of the entity or relationship whose fields are to be
displayed.

=item metadata

L<ERDB> metadata structure for the specified entity or
relationship.

=item RETURN

Returns a list of HTML lines that document the fields of the
specified object.

=back

=cut

sub DocFields {
    # Get the parameters.
    my ($self, $name, $metadata) = @_;
    # Declare the return variable.
    my @retVal;
    # Get the field hash.
    my $fields = $metadata->{Fields};
    # Create a heading for the field table. There is always at least
    # one field, so the heading will never be empty.
    push @retVal, $self->Heading(4, "$name Fields");
    # Generate the field table data.
    my ($header, $rows) = ERDB::ComputeFieldTable($self, $name, $fields);
    # Set up the header styles. They are all text.
    my @headerRow;
    for my $caption (@$header) {
        push @headerRow, text => $caption;
    }
    # Create the table.
    push @retVal, FancyTable(\@headerRow, @$rows);
    # Return the result.
    return @retVal;
}


=head3 ObjectHeading

    my $htmlLine = $self->ObjectHeading($type => $name);

This method will generate the heading line for an object block.

=over 4

=item type

Type of the object (C<entity>, C<relationship>, or C<shape>).

=item name

Name of the object whose heading is to be generated.

=item RETURN

Returns an HTML heading line for the named object.

=back

=cut

sub ObjectHeading {
    # Get the parameters.
    my ($self, $type, $name) = @_;
    # Compute the heading. Note we capitalize the type.
    my $retVal = $self->Heading(3, "$name " . ucfirst($type));
    # Return the result.
    return $retVal;
}

=head3 FancyTable

    my $html = ERDBPDocPage::FancyTable(\@cols, @rows);

Create a fancy html table. The first parameter is a hash-looking
thing that lists column styles and names, for example

    [text => 'User Name', text => 'Job Title', num => 'Salary']

The table rows should all be HTML-formatted.

=over 4

=item cols

Reference to a list of column names and styles. For each column,
the list should contain the column style (C<num>, C<text>, C<code>,
or C<center>) followed by the column title.

=item rows

List of table rows. Each row is a reference to a list of cells.

=item RETURN

Returns the html for the table.  The first row will be headings, and
the rest will be odd-even colored.

=back

=cut

sub FancyTable {
    # Get the parameters.
    my ($cols, @rows) = @_;
    # This will be a list of the column styles.
    my @styles;
    # This will be a list of the column headings.
    my @headings;
    # Create the column headings.
    for (my $i = 0; $i < scalar(@$cols); $i += 2) {
        push @styles, $cols->[$i];
        push @headings, $cols->[$i+1];
    }
    # Compute the number of columsn.
    my $colCount = scalar @styles;
    # We'll stash table heading cells in here.
    my @headCells;
    # Create the header row.
    for (my $i = 0; $i < $colCount; $i++) {
        push @headCells, CGI::th({ class => $styles[$i] }, $headings[$i]);
    }
    # Prime the table lines with the heading row.
    my @lines = (CGI::start_table({ class => 'fancy' }), CGI::Tr(@headCells));
    # This will be 1 for odd rows and 0 for even rows. The first row is odd.
    my $arity = 1;
    # Loop through the table rows.
    for my $row (@rows) {
        # Create a list of table cells for this row.
        my @cells;
        for (my $i = 0; $i < $colCount; $i++) {
            push @cells, CGI::td({ class => $styles[$i]}, $row->[$i]);
        }
        # Compute this row's style.
        my $class = ($arity ? 'odd' : 'even');
        $arity = 1 - $arity;
        # Form it into HTML and push it into the line list.
        push @lines, CGI::Tr({ class => $class }, @cells);
    }
    # Close the table.
    push @lines, CGI::end_table();
    # Return the result.
    my $retVal = join("\n", @lines);
    return $retVal;
}

=head3 Linked

    my $html = $self->Linked($objectName, $alias);

Generate a JavaScript link to the specified object. If an alias is
specified, it will be used in lieu of the object name as the link text.

=over 4

=item objectName

Name of the object to which a link is desired.

=item alias (optional)

Text to use for the link.

=item RETURN

Returns the HTML for an active object name.

=back

=cut

sub Linked {
    # Get the parameters.
    my ($self, $objectName, $alias) = @_;
    # Compute the link text.
    my $text = $alias || $objectName;
    # Compute the DIV identifier for the object.
    my $id = $self->_DivID($objectName);
    # Format the link.
    my $href = "javascript:ShowNewBlock($self->{javaThing}, '$id')";
    my $retVal = CGI::a({ href => $href }, $text);
    # Return the result.
    return $retVal;
}

=head3 BuildDiagram

    my $diagramHTML = $html->BuildDiagram($diagramData);

Create the HTML to display a database diagram. The incoming data object
contains the diagram width, height, and options. The data therein will be
used to generate a Flash movie of the database.

=over 4

=item diagramData

Hash containing the width (C<width>), height (C<height>), and other options
for displaying the diagram.

=item RETURN

Returns the HTML to display the database diagram.

=back

=cut

sub BuildDiagram {
    # Get the parameters.
    my ($self, $diagramData) = @_;
    # Declare the return variable.
    my @retVal;
    # We need a to create a script that outputs the DBD so that Flash
    # can read it.
    my $erdb = $self->{erdb};
    my $dbdFileName = $erdb->GetMetaFileName();
   # Compute the URL of the DBD.
    my $dbdURL = "$ERDBExtras::cgi_url/ErdbDbdPrint.cgi?xmlFileName=$dbdFileName";
    # Compute the height and width for the diagram.
    my $height = $diagramData->{height} || 800;
    my $width = $diagramData->{width} || 750;
    # Compute the option string. We remove height and width, and we explicitly
    # specify the link format.
    my @options;
    for my $key (keys %$diagramData) {
        if ($key ne 'height' && $key ne 'width') {
            push @options, qq($key="$diagramData->{$key}");
        }
    }
    push @options, 'links="javascript"';
    my $options = join(" ", @options);
    # Compute the base URL.
    my $base = "$ERDBExtras::cgi_url/ErdbDocWidget.cgi";
    # Compute the output string to be written by the script.
    my $dwriter = qq(<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" ) .
                  qq(codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,0,0" ) .
                  qq(width="$width" height="$height" id="Diagrammer.swf" align=""> <param name="allowScriptAccess" ) .
                  qq(value="sameDomain" /> <param name="allowFullScreen" value="false" /> ) .
                  qq(<param name="movie" value="$ERDBExtras::diagramURL" /> <param name="quality" value="high" /> ) .
                  qq(<param name="bgcolor" value="" /> <param name="base" value="$base" /> <param name="swliveconnect" value="" /> ) .
                  qq(<embed src="$ERDBExtras::diagramURL" quality="high" bgcolor="" width="$width" ) .
                  qq(height="$height" name="Diagrammer.swf" align="" base="$base" swliveconnect="" allowScriptAccess="sameDomain" ) .
                  qq(allowFullScreen="false" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" />) .
                  qq(</object>);
    # Generate the HTML for the flash movie. We have a method to pass in the
    # parameters and another the diagram can call to jump to a new location.
    push @retVal, '<script type="text/javascript">',
                  '  var stuff = "";',
                  '  function GetDiagramData() {',
                  '    return stuff;',
                  '  }',
                  '  function JavaJump(name) {',
                  "     var objectID = '$self->{idString}' + name;",
                  "     ShowNewBlock($self->{javaThing}, objectID);",
                  '  }',
                  "document.write('$dwriter');",
                  "stuff = '$base, $dbdURL, $options';",
                  '</script>';
    # Add the database notes below the diagram.
    push @retVal, ERDB::ObjectNotes($erdb->{_metaData}, $self);
    # Return the result.
    return join("\n", @retVal);
}


=head2 Wiki Markup Methods

The methods in this section create the appropriate HTML markup for ERDB
object notes. It allows this object to be used as a drop-in replacement
for L<WikiTools> when using the L<ERDB> documentation methods.

=head3 Heading

    my $line = $wiki->Heading($level, $text);

Return the code for a heading line at the specified level.

=over 4

=item level

Desired heading level.

=item text

Title for the heading's section.

=item RETURN

Returns a formatted heading line.

=back

=cut

sub Heading {
    # Get the parameters.
    my ($self, $level, $text) = @_;
    # Create the heading line.
    my $retVal = "<h$level>$text</h$level>";
    # Return the result.
    return $retVal;
}

=head3 Bold

    my $markup = $wiki->Bold($text);

Bold the specified text.

=cut

sub Bold {
    my ($self, $text) = @_;
    return CGI::strong($text);
}

=head3 Italic

    my $markup = $wiki->Italic($text);

Italicize the specified text.

=cut

sub Italic {
    my ($self, $text) = @_;
    return CGI::em($text);
}

=head3 LinkMarkup

    my $boldCode = $wiki->LinkMarkup($link, $text);

Returns the Wiki code for a link.

=over 4

=item link

URL or topic name referenced by the link.

=item text (optional)

Text of the link.

=back

=cut

sub LinkMarkup {
    # Get the parameters.
    my ($self, $link, $text) = @_;
    # Declare the return variable.
    my $retVal;
    # Check to see if we have text. If we don't, the URL is also
    # the text.
    my $actualText = (defined $text ? $text : $link);
    # Is this an internal link?
    if ($link =~ /^#(.+)/) {
        # Yes. Use our special format.
        $retVal = $self->Linked($1, $actualText);
    } else {
        # Form a normal link.
        $retVal = CGI::a({ href => $link }, $actualText);
    }
    # Return the result.
    return $retVal;
}

=head3 Table

    my $wikiText = $wiki->Table(@rows);

Create a Wiki table. The parameters are all list references. The first
describes the header row, and the remaining rows are presented
sequentially. This is a very simple table, using only default settings
and with everything left-aligned.

=over 4

=item rows

List of table rows. Each table row is a list reference containing the
cells of the row in column order. The first row is used as the header.

=item RETURN

Returns a string that will generate a Wiki table.

=back

=cut

sub Table {
    # Note that we treat the first row as column headers.
    my ($self, $headers, @rows) = @_;
    # Put the headers in the odd format expected by FancyTable.
    my @headList = map { (text => $_) } @$headers;
    # Format the table.
    my $retVal = FancyTable(\@headList, @rows);
    # Return the result.
    return $retVal;
}


=head3 List

    my $wikiText = $wiki->List(@items);

Create a Wiki list. The parameters are all strings that are put into the
list sequentially.

=over 4

=item items

List of items to be formatted into a wiki list.

=item RETURN

Returns wiki markup text that will display as an unordered list.

=back

=cut

sub List {
    # Get the parameters.
    my ($self, @items) = @_;
    # Format the list.
    my $retVal = CGI::ul(map { CGI::li($_) } @items);
    # Return the result.
    return $retVal;
}

=head3 Para

    my $markup = $wiki->Para($text);

Create a paragraph from the specified text.

=over 4

=item text

Text to format as a paragraph.

=item RETURN

Returns the text formatted as a paragraph.

=back

=cut

sub Para {
    my ($self, $text) = @_;
    return CGI::p($text);
}

=head2 Internal Utility Methods

=head3 _DivID

    my $id = $html->_DivID($objectName);

Return the DIV identifier for the specified entity, relationship, or
shape.

There is tension between this method and L</BuildDiagram>, because
the latter method must generate javascript to turn an object name
into an ID string.

=over 4

=item objectName

Name of the object whose DIV block identifier is desired.

=item RETURN

Returns the identifier for the named object's DIV block.

=back

=cut

sub _DivID {
    # Get the parameters.
    my ($self, $objectName) = @_;
    # Declare the return variable.
    my $retVal = $self->{idString} . $objectName;
    # Return the result.
    return $retVal;
}

1;
