package TestMethod;

    use lib::Web_Config;

=head3 TestMethod

Put code into this method to test simple PERL code. The value returned
will be dumped when you click the TEST button on the Method.html page.

=cut

sub TestMethod {
    return \@INC;
}

1;