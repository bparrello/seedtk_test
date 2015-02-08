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
    use File::Basename;
    use File::Spec;
    use Getopt::Long::Descriptive;

	# We don't have access to the normal SEEDtk libraries because
	# we are still bootstrapping. We do a "use lib" to get
	# addressability to the kernel packages.    
    use lib '../kernel';
    use Env;

	# We need to look inside the FIG_Config even though it is loaded at
	# run-time, so we will get lots of warnings about one-time variables.
	no warnings qw(once);
	
	## THESE TWO CONSTANTS DEFINE THE SCRIPT and PM LIBRARIES.
	use constant SCRIPTS => qw(utils);
	use constant LIBS => qw(ERDB kernel);

=head1 SEEDtk Configuration Utility

This method generates (or re-generates) the B<FIG_Config.pm> and B<UConfig.sh> files for a
SEEDtk environment.

The single positional parameter is the location of the data folder. This folder should
have a C<Data> subfolder containing the data files and a C<Web> folder containing the
web root. If a FIG_Config file already exists, this information is not needed-- the
existing values will be used.

The command-line options are as follows.

=over 4

=item fc

If specified, the name of the FIG_Config file for the output. If C<off>, no FIG_Config file
will be written.

=item uc

If specified, the name of the UConfig file for the output. If C<off>, no UConfig file
will be written. If C<sys>, the changes will be made directly to the environment (via
the registry). This last is only possible under Windows.

=item winmode

If C<1>, the system will be configured for Windows; if C<2>, the system will be configured for Unix.
If unspecified, the current operating system will be interrogated.

=back

=head2 Notes for Programmers

To add a new FIG_Config parameter, simply add a call to L<Env/WriteParam> to the
L</WriteAllParams> method.

To change the UConfig file, simply add a call to L<Env/WriteConfig> to the
L</WriteAllConfigs> method.


=cut

	$| = 1; # Prevent buffering on STDOUT.
	print "Retrieving current configuration.\n";
	# Get the directory this script is running it.
	my $base_dir = dirname(File::Spec->rel2abs(__FILE__));
	# Fix Windows slash craziness.
	$base_dir =~ tr/\\/\//;
	# Chop off the folder name to get the source root.
	$base_dir =~ s/\/\w+$//;
	# Determine the operating system.
	my $winMode = ($^O =~ /Win/ ? 1 : 0);
	# Analyze the command line.
	my ($opt, $usage) = describe_options('%o %c dataRootDirectory',
			["winmode|w=i", "\"1\" for Windows, \"0\" for Unix", { default => $winMode }],
			["fc=s", "name of a file to use for the FIG_Config output, or \"off\" to turn off FIG_Config output",
					{ default => "$base_dir/config/FIG_Config.pm" }],
			["uc=s", "name of a file to use for the UConfig output, \"off\" to turn off UConfig output, or \"sys\" to write directly to the environment",
					{ default => "$base_dir/config/UConfig.sh" }],
			);
	print "Analyzing directories.\n";
	# The data root directory will be put in here.
	my $dataRootDir = '';
	# Check for an existing FIG_Config. If there isn't one, we need to 
	# create it.
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
	#If the FIG_Config write has NOT been turned off, then write the FIG_Config.
	# write to a test file.
	if ($opt->fc eq 'off') {
		print "FIG_Config output suppressed.\n";
	} else {
		# Write the FIG_Config.
		WriteAllParams($opt->fc, $base_dir, $dataRootDir, $opt);
		# Execute it to get the latest variable values.
		print "Reading back new configuration.\n";
		RunFigConfig($opt->fc);
	}
	
	# If the UConfig write has NOT been turned off, then write the UConfig.
	if ($opt->uc eq 'off') {
		print "UConfig output suppressed.\n";
	} else {
		# Write the UConfig.
		WriteAllConfigs($opt->uc, $base_dir, $opt);
	}	
	print "All done.\n";
	if ($newUrls) {
		# Here new URL values were computed. Warn the user about updating them.
		print "If you are not hosting the web services locally, you may need to edit the URL parameters.\n";
	}
		
=head3 RunFigConfig

    RunFigConfig($fileName);

Execute the FIG_Config module. This uses the PERL C<do> function, which
unlike C<require> can execute a module more than once, but requires error
checking. The error checking is done by this method. If no parameter is
specified, the default FIG_Config is executed. If a parameter is specified,
it is used as the name of the file to execute.

=cut

sub RunFigConfig {
	# Get the parameters.
	my ($fileName) = @_;
	$fileName //= 'FIG_Config.pm'; 
	# Execute the FIG_Config;
	do $fileName;
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
    Env::WriteLines($oh,
    	"package FIG_Config;",
    	"",
    	"## WHEN YOU ADD ITEMS TO THIS FILE, BE SURE TO UPDATE utils/Configure.pl.",
    	"");
    # Write each parameter.
    Env::WriteParam($oh, "Temporary directory.", temp => "$dataRootDir/Web/Tmp");
    Env::WriteParam($oh, "URL for temporary directory.", temp_url => 'http://localhost/Tmp');
    Env::WriteParam($oh, "TRUE if we should create indexes before a table load (generally TRUE for MySQL, FALSE for PostGres)",
    		preIndex => 1);
    Env::WriteParam($oh, "default DBMS", dbms => "mysql");
    Env::WriteParam($oh, "database access port", dbport => 3306);
    Env::WriteParam($oh, "TRUE if we are using an old version of MySQL", mysql_v3 => 0);
    Env::WriteParam($oh, "default MySQL engine", default_mysql_engine => "InnoDB");
    Env::WriteParam($oh, "default database host", dbhost => "seed-db-write.mcs.anl.gov");
    Env::WriteParam($oh, "TRUE to turn off size estimates during table creation-- these are needed for MyISAM",
    		disable_dbkernel_size_estimates => 1);
    Env::WriteParame($oh, "mode for LOAD TABLE INFILE statements, usually LOCAL", load_mode => 'LOCAL');
    Env::WriteParam($oh, "TRUE for windows mode", win_mode => ($opt->winmode ? 1 : 0));
    Env::WriteParam($oh, "source project directory", source => $base_dir);
    ## Put new non-Shrub parameters here.
    # This next parameters use code, so are not subject to the usual Env::WriteParam logic. 
    WriteLines($oh, "", "# script directory list",
    		'our \@scripts = map { "$source/$_" } qw(' . join(" ", SCRIPTS) . ');', 
    		'our \@libs = map { "$source/$_" } qw(' . join(" ", LIBS) . ')');
    # Now comes the Shrub configuration section.
    WriteLines($oh, "", "# SHRUB CONFIGURATION", "");
    Env::WriteParam($oh, "base directory for database-related files", shrub_dir => "$dataRootDir/Data");
    Env::WriteParam($oh, "DBD location", shrub_dbd => "$base_dir/ERDB/ShrubDBD.xml");
    Env::WriteParam($oh, "signon info", userData => "seed/");
    Env::WriteParam($oh, "database name", shrubDB => "seedtk_shrub");
    ## Put new Shrub parameters here.
	# Write the trailer.
	Env::WriteLines($oh, "", "1;");
	# Close the output file.
	close $oh;
}

=head3 WriteAllConfigs

    WriteAllConfigs($fileName, $base_dir, $opt);

Write out the B<UConfig.sh> file. This file is used in Unix systems to
set up environment variables for PERL includes and execution paths. It
presumes the B<FIG_Config> file has been updated and L</RunFigConfig> has
been called to load its variables.

=over 4

=item fileName

Name of the output file. If C<sys>, then the updates will be made directly to
the system environment. This is only possible if the script is being run in
administrator mode in a Windows system.

=item base_dir

Name of the base directory for the source.

=item opt

Command-line options object.

=back

=cut

	use constant REGKEY => 'SYSTEM/CurrentControlSet/Control/Session Manager/Environment';

sub WriteAllConfigs {
    # Get the parameters.
    my ($fileName, $base_dir, $opt) = @_;
    # This will be the output file handle. We'll set it to the
    # environment cluster if we are writing to the registry.
    my $oh;
    if ($opt->uc ne 'sys') {
    	# Here we are writing to a file.
    	open($oh, ">$fileName") || die "Could not open UConfig file $fileName: $!";
    	print "Writing environment changes to $fileName.\n";
    } else {
    	# Here we are updating the registry.
    	$oh = Env->GetRegKey(HKLM => REGKEY);
    	print "Writing environment changes to registry.\n";
    }
    # Compute the script paths.
    my $paths = join(";", @FIG_Config::scripts);
    Env::WriteConfig($oh, "Add SEEDtk scripts to the execution path.", PATH => $paths, merge => ';');
    # Set the PERL libraries.
    my $libs = join(";", @FIG_Config::libs);
    Env::WriteConfig($oh, "Add SEEDtk libraries to the PERL library path.", PERL5LIB => $libs, merge => ';');
}


