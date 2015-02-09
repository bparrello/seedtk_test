#!/usr/bin/perl

    use strict;
    use lib 'lib';
    use Web_Config;
    use CGI;
    use TestUtils;
    use WebUtils;
    use XML::Simple;
    # Apache only includes the kernel library, and this script needs them all.
    use FIG_Config;
    BEGIN { unshift @INC, @FIG_Config::libs; }
    use Shrub;

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