#!/usr/bin/perl

    use strict;
    use lib 'lib';
    use CGI;
    use TestUtils;
    use WebUtils;
    use XML::Simple;

print CGI::header();
print CGI::start_html(-title => 'Test Page',
                      -style => { src => '/css/Basic.css' });

eval {
    # Get the script.
    my $cgi = CGI->new();
    my $script = $cgi->param('perlScript');
    # Declare the return variable.
    my $retVal;
    # Is there a script?
    if ($script) {
        # Yes, execute it and check for errors.
        eval($script);
        if ($@) {
            Die("SCRIPT ERROR: $@");
        }
    } else {
        # No, call the default test method.
        $retVal = TEST();
    }
    # Dump the result.
    print CGI::start_div({ id => 'Dump' });
    print TestUtils::Display($retVal, "Normal");
    print CGI::end_div();
};
if ($@) {
    print CGI::blockquote($@);
}
print CGI::end_html();

# Default test.
sub TEST {
    my $retVal;
    #---------------
    #### CODE IN HERE ####
    #---------------
    return $retVal;
}

1;