#!/usr/bin/env run_perl.sh

    use strict;
    use lib 'lib';
    use CGI;
    use TestUtils;
    use WebUtils;
    use XML::Simple;
    use TestMethod;
    use Shrub;		# This must go after "TestMethod" or it won't be found!

print CGI::header();
print CGI::start_html(-title => 'Test Page',
                      -style => { src => '/css/Basic.css' });

eval {
    # Get the script.
    my $cgi = CGI->new();
    my $struct = $cgi->param('structure');
    # Get the structure.
    my $retVal;
    if ($struct eq 'Shrub DBD') {
        $retVal = Shrub->new(offline => 1);
    } elsif ($struct eq 'Shrub Object') {
        $retVal = Shrub->new();
    } elsif ($struct eq 'TEST') {
        $retVal = TestMethod::TestMethod();
    } else {
        die "Unknown structure requested."
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


1;
