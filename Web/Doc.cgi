#!/usr/bin/perl -w

    use strict;
    use CGI;
    use Pod::Simple::HTML;
    use lib 'lib';
    use WebUtils;
    use FIG_Config;

=head1 Documentation Display

This script presents a form in which the user can enter a POD document or
PERL module name, The given document or module is then converted into HTML
and displayed. This provides a mechanism for access to the documentation
on the testing server.

The single CGI parameter is C<module>.

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
    if ($modName) {
        # Try to find the module.
        my $fileFound = FindPod($modName);
        if (! $fileFound) {
            push @lines, CGI::h3("Module $modName not found.");
        } else {
            # We have a file containing our module documentation.
            # Tell the user its name.
            push @lines, CGI::div({ class => 'heading'}, CGI::h1($modName));
            # Now we must convert the pod to hTML. To do that, we need a parser.
            my $parser = Pod::Simple::HTML->new();
            # Denote we want an index.
            $parser->index(1);
            # Make us the L-link URL.
            $parser->perldoc_url_prefix("index.cgi?module=");
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
            push @lines, CGI::div({ id => 'Dump' }, $pod);
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
    # Only proceed if this is a reasonable Pod name.
    if ($modName =~ /^(?:\w|::)+(?:\.pl)?$/) {
        # Convert the module name to a path.
        $modName =~ s/::/\//g;
        # Get a list of the possible file names for our desired file.
        my @files;
        if ($modName =~ /\.pl/) {
        	@files = map { "$_/$modName" } @FIG_Config::scripts;
        } else {
         	@files = map { ("$_/$modName.pod", "$_/$modName.pm", "$_/pods/$modName.pod") } @INC;
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