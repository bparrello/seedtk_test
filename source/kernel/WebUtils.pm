package WebUtils;

    use strict;
    use Carp;

    use base qw(Exporter);
    use vars qw(@EXPORT);
    @EXPORT = qw(Open Min Max Pad SetGraphic Default Trace ClearTrace Phrase Die
                 Between Conjoin);

=head2 Utility Methods

=head3 Clean

    my $cleaned = Tracer::Clean($string);

Clean up a string for HTML display. This not only converts special
characters to HTML entity names, it also removes control characters.

=over 4

=item string

String to convert.

=item RETURN

Returns the input string with anything that might disrupt an HTML literal
removed. An undefined value will be converted to an empty string.

=back

=cut

sub Clean {
    # Get the parameters.
    my ($string) = @_;
    # Declare the return variable.
    my $retVal = "";
    # Only proceed if the value exists.
    if (defined $string) {
        # Get the string.
        $retVal = $string;
        # Clean the control characters.
        $retVal =~ tr/\x00-\x1F/?/;
        # Escape the rest.
        $retVal = CGI::escapeHTML($retVal);
    }
    # Return the result.
    return $retVal;
}

=head EntityCoding

    my $coding = EntityCoding($char);

Return an HTML entity coding for the specified character. This means computing
the character's ACII code and setting up the C<&#> notation.

=over 4

=item char

Character to convert.

=item RETURN

Returns a numeric HTML entity code for the character.

=back

=cut

sub EntityCoding {
    # Get the parameter.
    my ($char) = @_;
    # Compute the ASCII code for the character.
    my $code = ord($char);
    # Create the entity code.
    my $retVal = "&#$code;";
    # Return the result.
    return $retVal;
}

=head3 Min

    my $min = Min($value1, $value2, ... $valueN);

Return the minimum argument. The arguments are treated as numbers.

=over 4

=item $value1, $value2, ... $valueN

List of numbers to compare.

=item RETURN

Returns the lowest number in the list.

=back

=cut

sub Min {
    # Get the parameters. Note that we prime the return value with the first parameter.
    my ($retVal, @values) = @_;
    # Loop through the remaining parameters, looking for the lowest.
    for my $value (@values) {
        if ($value < $retVal) {
            $retVal = $value;
        }
    }
    # Return the minimum found.
    return $retVal;
}

=head3 Max

    my $max = Max($value1, $value2, ... $valueN);

Return the maximum argument. The arguments are treated as numbers.

=over 4

=item $value1, $value2, ... $valueN

List of numbers to compare.

=item RETURN

Returns the highest number in the list.

=back

=cut

sub Max {
    # Get the parameters. Note that we prime the return value with the first parameter.
    my ($retVal, @values) = @_;
    # Loop through the remaining parameters, looking for the highest.
    for my $value (@values) {
        if ($value > $retVal) {
            $retVal = $value;
        }
    }
    # Return the maximum found.
    return $retVal;
}

=head3 Pad

    my $paddedString = Pad($string, $len, $left, $padChar);

Pad a string to a specified length. The pad character will be a
space, and the padding will be on the right side unless specified
in the third parameter.

=over 4

=item string

String to be padded.

=item len

Desired length of the padded string.

=item left (optional)

TRUE if the string is to be left-padded; otherwise it will be padded on the right.

=item padChar (optional)

Character to use for padding. The default is a space.

=item RETURN

Returns a copy of the original string with the pad character added to the
specified end so that it achieves the desired length.

=back

=cut

sub Pad {
    # Get the parameters.
    my ($string, $len, $left, $padChar) = @_;
    # Compute the padding character.
    if (! defined $padChar) {
        $padChar = " ";
    }
    # Compute the number of spaces needed.
    my $needed = $len - length $string;
    # Copy the string into the return variable.
    my $retVal = $string;
    # Only proceed if padding is needed.
    if ($needed > 0) {
        # Create the pad string.
        my $pad = $padChar x $needed;
        # Affix it to the return value.
        if ($left) {
            $retVal = $pad . $retVal;
        } else {
            $retVal .= $pad;
        }
    }
    # Return the result.
    return $retVal;
}

=head3 Default

    my $value = Default($parm, $default);

Return the specified parameter value, or the default value if the
specified value is null or undefined. Unlike OR operators, this method
will not convert 0 to the default.

=over 4

=item parm

Parameter value to examine.

=item default

Default value to use if the parameter is unspecified.

=item RETURN

Returns either the parameter value or the default value.

=back

=cut

sub Default {
    # Get the parameters.
    my ($parm, $default) = @_;
    # Declare the return variable.
    my $retVal = $parm;
    # Put in the default if we need to.
    if (! defined $retVal || $retVal eq '') {
        $retVal = $default;
    }
    # Return the result.
    return $retVal;
}

=head3 Trace

    Trace($message);

Write a message to the trace file.

=over 4

=item message

Message to write.

=back

=cut

sub Trace {
    # Get the parameters.
    my ($message) = @_;
    # Open the trace file.
    if (open my $oh, ">>$ENV{DOCUMENT_ROOT}/logs/trace.log") {
        # Write the message.
        print $oh "$message\n";
        # Close the file.
        close $oh;
    }
}

=head3 ClearTrace

    ClearTrace();

Erase the trace file.

=cut

sub ClearTrace {
    unlink "$ENV{DOCUMENT_ROOT}/logs/trace.log";
}

=head3 Die

    Die($message);

Abnormally terminate the process with the specified error message.

=over 4

=item message

Error message to display.

=back

=cut

sub Die {
    # Get the parameters.
    my ($message) = @_;
    # Terminate with an error.
    confess($message);
}

=head3 Open

    my $fh = Open($fileSpec);

Open the specified file, returning the file handle. If the open fails, an
error will be thrown.

=over 4

=item fileSpec

Open file specification, usually a file name preceded by a mode character.

=item RETURN

Returns the handle for the newly opened file.

=back

=cut

sub Open {
    # Get the parameters.
    my ($fileSpec) = @_;
    # Declare the variable to hold the file handle.
    my $retVal;
    # Attempt to open the file.
    my $ok = open $retVal, $fileSpec;
    # If the open failed, generate an error message.
    if (! $ok) {
        Die("File error: $!");
    }
    # Return the file handle.
    return $retVal;
}

=head3 Phrase

    my $phrase = Phrase($name);

Convert a name into a phrase. Spaces are inserted whenever there is a
transition from lower-case to upper-case.

=over 4

=item name

Name to be converted into a phrase.

=item RETURN

Returns a more displayable version of a camel-cased word.

=back

=cut

sub Phrase {
    # Get the parameters.
    my ($name) = @_;
    # Declare the return variable.
    my $retVal = $name;
    # Insert spaces.
    $retVal =~ s/([a-z])([A-Z])/$1 $2/g;
    # Return the result.
    return $retVal;
}

=head3 Conjoin

    my $name = Conjoin($phrase);

Remove the spaces and apostrophes from the specified phrase to create a name.

=over 4

=item phrase

Phrase to conjoin.

=item RETURN

Returns the incoming phrase with spaces removed.

=back

=cut

sub Conjoin {
    # Get the parameters.
    my ($phrase) = @_;
    # Copy the input.
    my $retVal = $phrase;
    # Delete the spaces and apostrophes
    $retVal =~ s/\s+|'//g;
    # Return the result.
    return $retVal;
}

=head3 Between

    my $flag = Between($min, $x, $max);

Return TRUE if the specified value is entirely between the minimum and maximum.
(In other words, the x-value cannot equal the min or the max.)

=over 4

=item min

Lower boundary for the value.

=item x

Value of interest.

=item max

Upper boundary for the value.

=item RETURN

Returns TRUE if the value of interest is between the boundaries.

=back

=cut

sub Between {
    # Get the parameters.
    my ($min, $x, $max) = @_;
    # Return the result.
    return (defined $x && $min < $x && $x < $max);
}

=head3 PutFields

    Tracer::PutFields($oh, @fields);

Write a list of fields to the output file. The fields are tab-delimited
with a following new-line.

=over 4

=item oh

Open handle of the output file.

=item fields

List of fields to write. The fields will be written as strings.

=back

=cut

sub PutFields {
    # Get the parameters.
    my ($oh, @fields) = @_;
    # Write the parameters to the output.
    print $oh join("\t", @fields) . "\n";
}


=head3 GetFields

    my @fields = Tracer::GetFields($ih, $count);

Read a list of fields from the input file. The fields should be
tab-delimited on a single line.

=over 4

=item ih

Open input file handle.

=item count (optional)

Number of fields expected. If undefined, no check of the number of fields will
be made.

=item RETURN

Returns the fields read from the file.

=back

=cut

sub GetFields {
    # Get the parameters.
    my ($ih, $count) = @_;
    # Insure it's safe to read.
    Die("File input error: unexpected end-of-file.")
        if eof $ih;
    # Read the next line from the file.
    my $line = <$ih>;
    # Fail on error.
    Die("File input error: $!")
        if ! defined $line;
    # Remove the line-ending character.
    chomp $line;
    # Split the fields.
    my @retVal = split("\t", $line);
    # Do we need to check the number of fields?
    if (defined $count) {
        # Get the number of fields found.
        my $found = scalar @retVal;
        # Verify it.
        Die("File input error: expected $count fields, but found $found.")
            if $found != $count;
    }
    # Return the result.
    return @retVal;
}

=head3 Cmp

    my $cmp = Tracer::Cmp($a, $b);

This method performs a universal sort comparison. Each value coming in is
separated into a text parts and number parts. The text
part is string compared, and if both parts are equal, then the number
parts are compared numerically. A stream of just numbers or a stream of
just strings will sort correctly, and a mixed stream will sort with the
numbers first. Strings with a label and a number will sort in the
expected manner instead of lexically. Undefined values sort last.

=over 4

=item a

First item to compare.

=item b

Second item to compare.

=item RETURN

Returns a negative number if the first item should sort first (is less), a positive
number if the first item should sort second (is greater), and a zero if the items are
equal.

=back

=cut

sub Cmp {
    # Get the parameters.
    my ($a, $b) = @_;
    # Declare the return value.
    my $retVal;
    # Check for nulls.
    if (! defined($a)) {
        $retVal = (! defined($b) ? 0 : -1);
    } elsif (! defined($b)) {
        $retVal = 1;
    } else {
        # Here we have two real values. Parse the two strings.
        my @aParsed = _Parse($a);
        my @bParsed = _Parse($b);
        # Loop through the first string.
        while (! $retVal && @aParsed) {
            # Extract the string parts.
            my $aPiece = shift(@aParsed);
            my $bPiece = shift(@bParsed) || '';
            # Extract the number parts.
            my $aNum = shift(@aParsed);
            my $bNum = shift(@bParsed) || 0;
            # Compare the string parts insensitively.
            $retVal = (lc($aPiece) cmp lc($bPiece));
            # If they're equal, compare them sensitively.
            if (! $retVal) {
                $retVal = ($aPiece cmp $bPiece);
                # If they're STILL equal, compare the number parts.
                if (! $retVal) {
                    $retVal = $aNum <=> $bNum;
                }
            }
        }
    }
    # Return the result.
    return $retVal;
}

# This method parses an input string into a string parts alternating with
# number parts.
sub _Parse {
    # Get the incoming string.
    my ($string) = @_;
    # The pieces will be put in here.
    my @retVal;
    # Loop through as many alpha/num sets as we can.
    while ($string =~ /^(\D*)(\d+)(.*)/) {
        # Push the alpha and number parts into the return string.
        push @retVal, $1, $2;
        # Save the residual.
        $string = $3;
    }
    # If there's still stuff left, add it to the end with a trailing
    # zero.
    if ($string) {
        push @retVal, $string, 0;
    }
    # Return the list.
    return @retVal;
}

=head3 Ordinal

    my $word = Tracer::Ordinal($number);

Return a string representing the ordinal corresponding to the specified
number. C<0> becomes C<first>, C<1> becomes C<second>, and so forth.

=over 4

=item number

Index number to be converted to an ordinal word.

=item RETURN

Returns a string that can be used to represent the index number as a
humanly familiar ordinal position.

=back

=cut

use constant SMALLS => { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth',
                         5 => 'fifth', 6 => 'sixth', 7 => 'seventh', 8 => 'eighth',
                         9 => 'ninth', 10 => 'tenth', 11 => 'eleventh',
                         12 => 'twelfth' };
use constant DIGITS => ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'];

sub Ordinal {
    # Get the parameters.
    my ($number) = @_;
    # Compute the real ordinal.
    my $pos = $number + 1;
    # Process small numbers.
    my $retVal = SMALLS->{$pos};
    # If it's not small, we need to process the last digit.
    if (! defined $retVal) {
        $retVal = $pos . DIGITS->[$retVal % 10];
    }
    # Return the result.
    return $retVal;
}


1;
