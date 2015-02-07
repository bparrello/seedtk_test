#!/usr/bin/perl -w

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

    use strict;
    use Stats;
    use File::Basename;
    use File::Spec;
    use Getopt::Long::Descriptive;
    no warnings qw(once);
    

=head1 SEEDtk Configuration Utility

This method generates (or re-generates) the B<FIG_Config.pm> and B<UConfig.sh> files for a
SEEDtk environment.

The single positional parameter is the location of the data folder. This folder should
have a C<Data> subfolder containing the data files and a C<Web> folder containing the
web root. If a FIG_Config file already exists, this information is not needed-- the
existing values will be used.

To add a new FIG_Config parameter, simply add a call to L</WriteParam> to the
L</WriteAllParams> method.

To change the UConfig file, modify the sequence of print statements in L</WriteConfig>
method.  

=cut

	$| = 1; # Prevent buffering on STDOUT.
	# Analyze the command line.
	my ($opt, $usage) = describe_options('%o %c dataRootDirectory',
			["winmode|w", "if specified, a windows-mode configuration is generated"]);
	print "Analyzing directories.\n";
	# Get the directory this script is running it.
	my $base_dir = dirname(File::Spec->rel2abs(__FILE__));
	# Fix Windows slash craziness.
	$base_dir =~ tr/\\/\//;
	# Chop off the folder name to get the source root.
	$base_dir =~ s/\/\w+$//;
	# The data root directory will be put in here.
	my $dataRootDir = '';
	# Check for an existing FIG_Config. If there isn't one, we need to 
	# create it.
	print "Retrieving current configuration.\n";
	my $fig_config_name = "$base_dir/config/FIG_Config.pm";
	if (! -f $fig_config_name) {
		# Creatge an empty FIG_Config file.
		my $fh = Tracer::Open(undef, ">$fig_config_name");
		print "package FIG_Config\n";
		print "1;";
		close $fh;
	}
	# Now load the existing FIG_Config variables.
	RunFigConfig();
	# Do we have URL values? If not, remember it.
	my $newUrls = (! defined $FIG_Config::temp_url);
	# Make sure we have the data directories if there is no data root
	# in the command-line parameters.
	if (! defined $FIG_Config::shrub_dir) {
		$dataRootDir = $ARGV[0];
		if (! defined $dataRootDir) {
			die "A data root directory is required if no current values exist in FIG_Config.";
		} elsif (! -d $dataRootDir) {
			die "The specified data root directory $dataRootDir was not found.";
		}
	}
	# Write the FIG_Config.
	print "Writing $fig_config_name.\n";
	WriteAllParams($fig_config_name, $base_dir, $dataRootDir, $opt);
	# Execute it to get the latest variable values.
	print "Reading back new configuration.\n";
	RunFigConfig();
	# Write the UConfig.
	WriteConfig($base_dir, $opt);
	print "All done.\n";
	if ($newUrls) {
		# Here new URL values were computed. Warn the user about updating them.
		print "If you are not hosting the web services locally, you may need to edit the URL parameters.\n";
	}
	
		
=head3 RunFigConfig

    RunFigConfig();

Execute the FIG_Config module. This uses the PERL C<do> function, which
unlike C<require> can execute a module more than once, but requires error
checking. The
error checking is done by this method.

=cut

sub RunFigConfig {
	# Execute the FIG_Config;
	do 'FIG_Config.pm';
	if ($@) {
		# An error occurred compiling the module.
		die "Error compiling FIG_Config: $@";
	} elsif ($!) {
		# An error occurred reading the module.
		die "Error reading FIG_Config: $!";
	}
}

=head3 WriteAllParams

    WriteAllParams($fig_config_name, $base_dir, $dataRootDir, $opt);

Write out the B<FIG_Config> file to the specified location. This method
is mostly calls to the L</WriteParam> method, which provides a concise
way of writing parameters to the file and checking for pre-existing
values. It is presumed that L</RunFigConfig> has been executed first so
that the existing values are known.

=over 4

=item fig_config_name

File name for the B<FIG_Config> file. The parameter code will be written to
this file.

=item base_dir

Location of the base directory for the source code.

=item dataRootDir

Location of the base directory for the data and web files.

=item opt

Command-line options object.

=back

=cut

sub WriteAllParams {
    # Get the parameters.
    my ($fig_config_name, $base_dir, $dataRootDir, $opt) = @_;
    # Open the FIG_Config for output.
    my $oh = Tracer::Open(undef, ">$fig_config_name");
    # Write the initial lines.
    WriteLines($oh,
    	"package FIG_Config;",
    	"",
    	"## WHEN YOU ADD ITEMS TO THIS FILE, BE SURE TO UPDATE utils/Configure.pl.",
    	"");
    # Write each parameter.
    WriteParam($oh, "Temporary directory.", temp => "$dataRootDir/Web/Tmp");
    WriteParam($oh, "URL for temporary directory.", temp_url => 'http://localhost/Tmp');
    WriteParam($oh, "TRUE if we should create indexes before a table load (generally TRUE for MySQL, FALSE for PostGres)",
    		preIndex => 1);
    WriteParam($oh, "default DBMS", dbms => "mysql");
    WriteParam($oh, "database access port", dbport => 3306);
    WriteParam($oh, "TRUE if we are using an old version of MySQL", mysql_v3 => 0);
    WriteParam($oh, "default MySQL engine", default_mysql_engine => "InnoDB");
    WriteParam($oh, "default database host", dbhost => "seed-db-write.mcs.anl.gov");
    WriteParam($oh, "TRUE to turn off size estimates during table creation-- these are needed for MyISAM",
    		disable_dbkernel_size_estimates => 1);
    WriteParame($oh, "mode for LOAD TABLE INFILE statements, usually LOCAL", load_mode => 'LOCAL');
    WriteParam($oh, "TRUE for windows mode", win_mode => ($opt->winmode ? 1 : 0));
    WriteParam($oh, "source project directory", source => $base_dir);
    ## Put new non-Shrub parameters here.
    # This next parameter uses code, so it is not subject to the usual WriteParam logic. 
    WriteLines($oh, "", "# script directory list",
    		'our \@scripts = map { "$source/$_" } qw(utils)');
    # Now comes the Shrub configuration section.
    WriteLines($oh, "", "# SHRUB CONFIGURATION", "");
    WriteParam($oh, "base directory for database-related files", shrub_dir => "$dataRootDir/Data");
    WriteParam($oh, "DBD location", shrub_dbd => "$base_dir/ERDB/ShrubDBD.xml");
    WriteParam($oh, "signon info", userData => "seed/");
    WriteParam($oh, "database name", shrubDB => "seedtk_shrub");
    ## Put new Shrub parameters here.
	# Write the trailer.
	WriteLines($oh, "", "1;");
	# Close the output file.
	close $oh;
}

=head3 WriteConfig

    WriteConfig($base_dir, $opt);

Write out the B<UConfig.sh> file. This file is used in Unix systems to
set up environment variables for PERL includes and execution paths. It
presumes the B<FIG_Config> file has been updated and L</RunFigConfig> has
been called to load its variables.

=over 4

=item base_dir

Name of the base directory for the source.

=item opt

Command-line options object.

=back

=cut

sub WriteConfig {
    # Get the parameters.
    my ($base_dir, $opt) = @_;
    ##TODO: Code for WriteConfig
}


=head3 WriteLines

    WriteLines($oh, @lines);

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

    WriteParam($oh, $comment, $varName => $defaultValue);

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
								( "\r" => "\\r", "\n" => "\\n", "\t" => "\\t"),
								( map { chr($_) =>"\\x" . unpack('H2', chr($_)) => chr($_) } (0..255) ) };

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





	