#!/usr/bin/perl

    use strict;
    use lib 'lib';
    use Web_Config;
    use CGI;
    use TestUtils;
    use WebUtils;
    use XML::Simple;
    # Web_Config only includes the kernel library, and this script needs them all.
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
    } elsif ($struct eq 'TEST') {
    	$retVal = TestMethod();
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

=head3 TestMethod

Put code into this method to test simple PERL code. The value returned
will be dumped.

=cut

sub TestMethod {
	my @strings = qw(abcdefg 1234567);
	my $retVal = [ map { substr($_, -3, 3) } @strings ];
	return $retVal;
}

1;