
use strict;

use Data::Dumper;
use FreezeThaw qw(freeze);
use ERDB;
use CGI;

my $cgi = new CGI;

my $db = $cgi->param('db');
my $op = $cgi->param('op');
my $path = $cgi->param('path');
my $filter = $cgi->param('filter');
my @params = $cgi->param('params');
my @fields = $cgi->param('fields');
my $count = $cgi->param('count');

if ($op eq 'Get')
{
    print $cgi->header;
    do_get($db, $path, $filter, \@params, \@fields, $count);
}

sub do_get
{
    my($db, $path, $filter, $params, $fields, $count) = @_;

    my $erdb = ERDB::GetDatabase($db);

    if ($count > 0)
    {
	$filter .= " LIMIT $count";
    }

    my $res = $erdb->Get($path, $filter, $params);
#    print Dumper($res);

    while (my $rec = $res->Fetch())
    {
	my %out;
	for my $field (@fields)
	{
	    $out{$field} = [$rec->Value($field)];
	}
	#print Dumper(\%out);
	# my $flat = Dumper(\%out);
	my $flat = freeze(\%out);
	my $l = length($flat);
	print "$l\n$flat";
    }
}
