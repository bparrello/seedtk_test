#!/usr/bin/env run_perl.sh

    use strict;
    use CGI;
    use Pod::Simple::HTML;
    use lib 'lib';
    use WebUtils;
    use Web_Config;
    use Env;

=head1 Documentation Display

This script presents a form in which the user can enter a POD document or
PERL module name, The given document or module is then converted into HTML
and displayed. This provides a mechanism for access to the documentation
on the testing server.

The single CGI parameter is C<module>.

Several special module names give special results.

=over 4

=item FIG_Config

Display the project configuration parameters.

=item ENV

Display the system environment.

=item scripts

Display a list of the available command-line scripts.

=back

=cut

# Get the CGI query object.
my $cgi = CGI->new();
# Start the output page.
print CGI::header();
print CGI::start_html(-title => 'Documentation Page',
                      -style => { src => '/css/Basic.css' });
# Specify a borderless body.
print CGI::start_body({ class => 'borderless' });
# Clear the trace file.
ClearTrace();
# Protect from errors.
eval {
    # We'll put the HTML text in here.
    my @lines;
    # Do we have a module?
    my $modName = $cgi->param('module');
    if ($modName eq 'FIG_Config') {
    	# Here the user wants a dump of the FIG_Config. Get the data we need.
    	my $configHash = Env::GetFigConfigs("$FIG_Config::source/config/FIG_Config.pm");
    	# Start with a heading.
    	push @lines, CGI::div({ class => 'heading' }, CGI::h1("FIG_Config"));
    	# Start the output table.
    	push @lines, CGI::start_div({ id => 'Dump' }),
    			CGI::start_table({ class => 'vars' }),
    			CGI::Tr(CGI::th(['name', 'description', 'value']));
    	# Loop through the variables, adding table rows.
    	for my $var (sort keys %$configHash) {
    		my $varData = $configHash->{$var};
    		push @lines, CGI::Tr(CGI::td([$var, @$varData]));
    	}
    	# Close off the table.
    	push @lines, CGI::end_table(), CGI::br({ class => 'clear' });
    	# Close off the display area.
    	push @lines, CGI::end_div();
    } elsif ($modName eq 'ENV') {
    	# Here the user wants a dump of the environment variables.
    	push @lines, CGI::div({ class => 'heading' }, CGI::h1("System Environment"));
    	# Start the output table.
    	push @lines, CGI::start_div({ id => 'Dump' }),
    			CGI::start_table({ class => 'vars' }),
    			CGI::Tr(CGI::th(['name', 'value']));
    	# Loop through the environment variables, writing them out.
    	for my $key (sort keys %ENV) {
    		push @lines, CGI::Tr(CGI::td([$key, $ENV{$key}]));
    	}
    	# Close off the table.
    	push @lines, CGI::end_table(), CGI::br({ class => 'clear' });
    	# Close off the display area.
    	push @lines, CGI::end_div();
    } elsif ($modName eq 'scripts') {
    	# Here the user wants a list of the command-line scripts.
    	push @lines, CGI::div({ class => 'heading'}, CGI::h1("Command-Line Scripts"));
    	push @lines, CGI::start_div({ id => 'Dump' });
    	# Loop through the script directories.
    	for my $dir (@FIG_Config::scripts) {
    		# Get the base name of the path and use it as our section title.
    		$dir =~ /(\w+)$/;
    		push @lines, CGI::h2($1);
			# Get a hash of the scripts in this directory.
			my $scriptHash = Env::GetScripts($dir);
			if (! scalar keys %$scriptHash) {
				# Here there are none.
				push @lines, CGI::p("No documented scripts found.");
			} else {
				# We need to loop through the scripts, displaying them.
				# This variable will count undocumented scripts.
				my @undoc;
				# This variable will count documented scripts.
				my $doc = 0;
				# Do the looping.
				for my $script (sort keys %$scriptHash) {
					# Get the comment.
					my $comment = $scriptHash->{$script};
					# Are we documented?
					if ($comment) {
						# Yes. If this is the first one, start the list.
						if (! $doc) {
							push @lines, CGI::start_ol();
						}
						# Count this script and display it.
						push @lines, CGI::li({ class => 'item' }, CGI::a({ href => "Doc.cgi?module=$script" }, $script) . 
								": $comment");
						$doc++;
					} else {
						# Undocumented script. Just remember it.
						push @undoc, $script; 
					}
				}
				# If we had documented scripts, close the list.
				if ($doc) {
					push @lines, CGI::end_ol();
				}
				# If we had undocumented scripts, list them.
				if (scalar @undoc) {
					push @lines, CGI::p("Undocumented scripts: " . join(", ", @undoc));
				}
			}
    	}
    	# Close off the display.
    	push @lines, CGI::end_ul(), CGI::br({ class => 'clear' }), CGI::end_div();
	} elsif ($modName) {
        # Here we have a regular module. Try to find it.
        my $fileFound = FindPod($modName);
        if (! $fileFound) {
            push @lines, CGI::h3("Module $modName not found.");
        } else {
            # We have a file containing our module documentation.
            # Tell the user its name.
            push @lines, CGI::div({ class => 'heading'}, CGI::h1($modName));
            # Now we must convert the pod to HTML. To do that, we need a parser.
            my $parser = Pod::Simple::HTML->new();
            # Denote we want an index.
            $parser->index(1);
            # Make us the L-link URL.
            $parser->perldoc_url_prefix("Doc.cgi?module=");
            # Denote that we want to format the Pod into a string.
            my $pod;
            $parser->output_string(\$pod);
            # Parse the file.
            $parser->parse_file($fileFound);
            # Check for a meaningful result.
            if ($pod !~ /\S/) {
                # No luck. Output an error message.
                $pod = CGI::h3("No POD documentation found in <u>$modName</u>.");
            }
            # Put the result in the output area.
            push @lines, CGI::div({ id => 'Dump' }, $pod, CGI::br({ class => 'clear' }));
        }
    }
    print join("\n", @lines);
};
# Process any error.
if ($@) {
    print CGI::blockquote($@);
}
# Close off the page.
print CGI::end_html();

=head3 FindPod

    my $fileFound = FindPod($modName);

Attempt to find a POD document with the given name. If found, the file
name will be returned.

=over 4

=item modName

Name of the Pod module.

=item RETURN

Returns the name of the POD file found, or C<undef> if no such file was found.

=back

=cut

sub FindPod {
    # Get the parameters.
    my ($modName) = @_;
    # Declare the return variable.
    my $retVal;
    # Insure the name is reasonable.
    if ($modName =~ /^(?:\w|::)+(?:\.pl)?$/) {
        # Convert the module name to a path.
        $modName =~ s/::/\//g;
        # Get a list of the possible file names for our desired file.
        my @files;
        if ($modName =~ /\.pl/) {
        	@files = map { "$_/$modName" } @FIG_Config::scripts;
        } else {
         	@files = map { ("$_/$modName.pod", "$_/$modName.pm", "$_/pods/$modName.pod") } @INC;
         	push @files, map { ("$_/$modName.pod", "$_/$modName.pm") } @FIG_Config::libs;
		}
        # Find the first file that exists.
        for (my $i = 0; $i <= $#files && ! defined $retVal; $i++) {
            # Get the file name.
            my $fileName = $files[$i];
            # Fix windows/Unix file name confusion.
            $fileName =~ s#\\#/#g;
            if (-f $fileName) {
                $retVal = $fileName;
            }
        }
    }
    # Return the result.
    return $retVal;
}


1;