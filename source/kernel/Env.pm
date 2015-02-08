package Env;

    use strict;
    
    # This prevents a compiler warning for the registry stuff if we end up
    # not loading Win32::Registry.
{
   	package main;
   	use vars qw($HKEY_LOCAL_MACHINE $HKEY_CURRENT_USER $HKEY_CLASSES_ROOT);
}

=head1 Environment Modification Utilities

This package contains utility methods for modifying the environment. This includes
methods for writing assignment statements to files and changing the Windows
registry. The Windows stuff is only loaded if it's required. We
use L<Win32::Registry> rather than the newer B<TieRegistry> module because
the newer one does not always work. Note that you must be running as an
administrator if you are trying to update the registry.

The SEEDtk environment requires win-bash and the GnuWin32 tools in order
to run under Windows. This means the configuration file formats are
identical between the two environments.

=head2 Registry Methods

=head3 GetRegKey

	my $keyStructure = Environment->GetRegKey($root => $path);

Return a L<Win32::Registry> structure for manipulating the values of a
particular registry key.

=over 4

=item root

Root of the registry section of interest. Permissible values are C<HKLM>
(HKEY_LOCAL_MACHINE), C<HKCR> (HKEY_CLASSES_ROOT), and C<HKCU>
(HKEY_CURRENT_USER).

=item path

Path from the root to the registry key. Either slashes C</> or
backslashes C<\> can be used as delimiters between path segments.

=item RETURN

Returns a L<Win32::Registry> object for manipulating the key in question.  

=back

=cut

sub GetRegKey {
	# Get the parameters.
	my ($class, $root, $path) = @_;
	# Insure we have access to the registry stuff.
	require Win32::Registry;
	# Get the root variable.
	my $rootKey;
	if ($root eq 'HKLM') {
		$rootKey = $::HKEY_LOCAL_MACHINE;
	} elsif ($root eq 'HKCR') {
		$rootKey = $::HKEY_CLASSES_ROOT;
	} elsif ($root = 'HKCU') {
		$rootKey = $::HKEY_CURRENT_USER;
	}
	# Normalize the path. We convert slashes to backslashes and insure there is one at the end.
	$path =~ tr/\//\\/;
	if (substr($path, -1) ne "\\") {
		$path .= "\\";
	}
	# Ask for the registry key.
	my $retVal;
	$rootKey->Open($path, $retVal);
	# Return it to the caller.
	return $retVal;
}

##TODO: GetRegValues, SetRegValue

=head2 Parameter Output Methods

=head3 WriteLines

    Env::WriteLines($oh, @lines);

Write one or more lines of text to the specified output file. Nonblank
lines will be indented four spaces.

=over 4

=item oh

Open file handle for writing to the B<FIG_Config> file.

=item lines

List of text lines to write. They will all be indented four spaces and followed by new-lines.

=back

=cut

sub WriteLines {
    # Get the parameters.
    my ($oh, @lines) = @_;
    # Loop through the lines.
    for my $line (@lines) {
    	# If the line is nonblank, pad it on the left.
    	if ($line =~ /\S/) {
    		$line = "    $line";
    	}
    	# Write the line.
    	print "$line\n";
    }
}


=head3 WriteParam

    Env::WriteParam($oh, $comment, $varName => $defaultValue);

Write a parameter value to the B<FIG_Config>. If the parameter already
has a value, that will be written. Otherwise, the default value will be
written. The value will be preceded by the comment.

=over 4

=item oh

Open output file handle for the B<FIG_Config> file.

=item comment

Comment to write out before the assignment statement.

=item varName

Name of the variable to assign.

=item defaultValue

Value to assign to the variable if it does not already have one.

=back

=cut

    # Table for escaping quoted strings.
    use constant BACKSLASH => { ( map { $_ => "\\$_" } ( '\\', '"', '$', '@' ) ),
								( map { chr($_) => "\\x" . unpack('H2', chr($_)) } (0..31, 128..255) ),
								( "\r" => "\\r", "\n" => "\\n", "\t" => "\\t")
    						  };

sub WriteParam {
    # Get the parameters.
    my ($oh, $comment, $varName, $defaultValue) = @_;
    # We will put the desired variable value in here.
    my $value = eval("\$FIG_Config::$varName");
    if ($@) {
    	die "Error checking value of FIG_Config::$varName";
    }
    if (! defined $value) {
    	# There is no existing value, so use the default.
    	$value = $defaultValue;
    }
    # Convert the value to PERL.
    if ($value !~ /^\d+$/) {
    	# Here the value is not a number. Convert it to backslashed form and quote it.
    	my @output = ('"');
    	for my $ch (split //, $value) {
    		push @output, (BACKSLASH->{$ch} // $ch);
    	}
    	$value = join("", @output, '"');
    }
    # Write a blank line followed by the parameter's comment and value.
    WriteLines($oh, "", $comment, "our $varName = $value");
}


=head3 WriteConfig

	Env::WriteConfig($oh, $comment, $varName, $value, %options);

Write a configuration parameter. This may involve output to a file or
an update to the registry environment. Because we use a bash emulator
in Windows, the file output syntax is very similar in both ebvironments.

=over 4

=item oh

Either an open file handle to which we should write the parameter or
a L<Win32::Registry> object for managing the Windows environment strings.

=item comment

A description of what the environment variable means.

=item varName

The name of the environment variable to set.

=item value

The value to give to the environment variable.

=item options

A hash of options that modify the write operation. The following keys
are supported.

=over 8

=item merge

If specified, the value is presumed to be a list that is merged into the
configuration. The value of the option is the list delimiter. In the
registry update case, this is an imperfect system, since if the
values to be merged change, old data could be left behind. 

=item expanded

If TRUE, then the value will be stored as an expanded string if it is
stored in the registry. Expanded strings allow %-variable substitution.

=back

=back

=cut

sub WriteConfig {
	# Get the parameters.
	my ($oh, $comment, $varName, $value, %options) = @_;
	# Check for a merge delimiter.
	my $delim = $options{merge};
	# Determine whether this is a registry update or a write.
	if (ref $oh ne 'Win32::Registry') {
		# Here we have an output file.
		# Write the comment.
		print $oh "# $comment\n";
		# Is this a merge?
		if ($delim) {
			# Yes. Write a command to prefix the new information.
			print $oh "export $varName=$value$delim%$varName%\n";
		} else {
			# No. Write a command to store the new information.
			print $oh "export $varName=$value\n";
		}
	} else {
		# Here we have a registry update. There is no comment. We'll
		# put the target value in here.
		my $actualValue = $value;
		# If this is a merge, we need to parse the existing value and
		# merge the new values in;
		if ($delim) {
			# Parse the incoming value.
			my %items = map { $_ => 1 } split $delim, $value;
			# Get the current environment value and parse it as well,
			# removing values found in @items.
			my @current = grep { ! $items{$_} } split $delim, $ENV{$varName};
			# Form a new value.
			$actualValue = join($delim, $value, @current);
		}
		# Determine the type of string being stored. 2 = expanded string,
		# 1 = string.
		my $type = ($options{expanded} ? 2 : 1);
		# Store the new value in the registry. The 0 in the parameter list
		# is a weird reserved parameter that has no effect but is still
		#required.
		$oh->SetValueEx($varName, 0, $type, $actualValue);
	}
}

1;