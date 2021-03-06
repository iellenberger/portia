package Portia::Tools;
use base Exporter;

@EXPORT_OK = qw(
	source
	uniq interpolate match
	indent undent
	trim
);

#use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use Cwd qw( abs_path getcwd );
use Data::Dumper;
use English;
use FindBin qw( $RealScript );
use iTools::Term::ANSI qw( color );
use iTools::System qw( die system );
use Storable qw( dclone retrieve );

use strict;
use warnings;

# === Class-Level Variables =================================================
# --- configuration for source ---
our $sourceConfig = {
	'import' => 1,      # import keys into %ENV   (bool)
	tmpfile  => undef,  # laternate tmpfile name  (string)
};

# === Exported Functions ====================================================
# --- 'source' a Bash script, importing environment variables ---
sub source {
	# --- process incoming parameters ---
	#    hashrefs are configuration for the sub
	#    arrayrefs are a list of filenames
	#    all other args are individual filenames
	my ($config, @scripts) = (dclone $sourceConfig, ());
	foreach my $arg (@_) {
		if    (ref $arg eq 'HASH')  { $config->{lc $_} = $arg->{$_} foreach keys %$arg; }
		elsif (ref $arg eq 'ARRAY') { push @scripts, @$arg; }
		else                        { push @scripts, $arg; }
	}

	# --- prececlare a few vars ---
	my $env     = $config->{'import'} ? \%ENV : {};
	my $tmpfile = $config->{tmpfile} ||= ($ENV{TMP_DIR} || '/tmp') ."/$RealScript.PTsource.$PID";

	# --- loop through each script, importing variables ---
	#! BUG: if import = 0 && @scripts > 1, values won't propagate to subsequent scripts
	foreach my $script (@scripts) {

		# --- don't try to run a script unless it exists ---
		#! TODO: make this optionally warn or fatal
		next unless -e $script;

		# --- run the script ---
		system qq[
			set -a
			source $script
			perl -e 'use Storable; store \\\%ENV, "$tmpfile"'
		];

		# --- throw an error if things didn't get sourced properly ---
		unless (-e $tmpfile) {
			my $dumper = new Data::Dumper([$config], ['config']);
			$dumper->Indent(0)->Sortkeys(1)->Terse(1);
			print undent("
				". color('*r', "portia internal error:") ." error sourcing shell script
				   while calling ". __PACKAGE__ ."::source(
				      ". $dumper->Dump($config) .",
				      '". abs_path(getcwd ."/$script") ."'
				   )

				If you're seeing this message, it's likely the file you are trying to source
				has an 'exit' command in it that's messing things up.  The 'exit' command is
				not allowed outside of functions in Portia configuration files.
			");
			die "tmpfile '$tmpfile' does not exist";
		}

		# --- retrieve the new env hash and delete the tempfile ---
		my $newenv = retrieve $tmpfile;
		unlink $tmpfile;

		# --- import new/changed envvars ---
		#! TODO: allow user to specify a specific list of variables to import
		#! TODO: allow the user to expand, contract or replace this list
		my $ignore = join '|', qw( _ PWD SHLVL USER );  # ignore certain values

		# --- copy new/changed values ---
		foreach my $key (keys %$newenv) {
			next if $key =~ /^(?:$ignore)$/;
			$env->{$key} = $newenv->{$key}
				if !exists $ENV{$key} || !defined $ENV{$key} || $ENV{$key} ne $newenv->{$key};
		}
	}

	return $env;
}

# --- reduce array to unique values ---
sub uniq { my %h; grep { !$h{$_}++ } @_ }

# --- interpolate hash into a block of text ---
sub interpolate {
	my $text = shift;                    # text to interpolate values into
	my $hash = shift || \%ENV;           # interpolation hash, default to %ENV
	while (my ($k, $v) = each %$hash) {  # loop through interpolation hash
		$text =~ s/\$\{$k}/$v/msg;        # replace keys in text with hash values
	}
	return $text;                        # return rewritten text
}

#! TODO: allow array AND arrayrefs as params
sub match {
	my $query = shift;
	# --- make sure the query is a compiled regex ---
	$query = qr/^$query$/ unless ref $query eq "Regexp";

	# --- assemble an array of values to match ---
	my $array = ref $_[0] ? $_[0] : [ @_ ];

	# --- search the array of values for a match ---
	foreach my $value (@$array) {
		# --- match found ---
		return 1 if $value =~ $query;
	}

	# --- no match found ---
	return 0;
}

# --- indent a block of text ---
sub indent { 
	my ($indent, $text) = @_; 

	# --- generate a number of spaces if $indent is numeric ---
	$indent = ' ' x $indent if $indent =~ /^\d+$/; 

	# --- indent the text ---
	$text =~ s/^/$indent/mg; 

	# --- remove spaces from whitespace-only lines ---
	$text =~ s/^\s+$//mg; 

	return $text; 
} 

# --- un-indent a block of text ---
sub undent {
	my $text = shift;

	# --- replace tabs with 4 spaces ---
	#$text =~ s/\t/    /g;

	# --- find the smallest indent ---
	my $indent = ' ' x 100;
	foreach my $line (split /\n/, $text) {
		next unless $line =~ /^(\s*)\S/;  # ignore blank lines
		$indent = $1 if length($1) < length($indent);
	}

	# --- unindent the block of text ---
	$text =~ s/^$indent//mg;

	# --- trim leading and trailing space (multiline) ---
	$text =~ s/^\s*\n//s;
	$text =~ s/[\t ]*$//msg;
	return '' unless $text;

	return $text;
}

# --- trim leading and trailing space (string context) ---
sub trim {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

1;

=head1 NAME

Portia::Tools - Perl-based tools to support Portia

=head1 SYNPOSIS

use Portia::Tools qw( source uniq interpolate match indent undent trim );

=head1 DESCRIPTION

Portia::Tools provides a number of commonly reused functions used in Portia.

=head1 EXPORTED FUNCTIONS

=over 4

=item B<source>(SCRIPT [, ...])

This is the Perl equivalent of the Bash 'source' command.
It executes the given Bash SCRIPT and imports modified environment variables into the Perl's %ENV.

If you specify more than one SCRIPT, these will be executed and imported in sequence.

=item B<uniq>(ARRAY)

Returns an array of unique values.
The returned array maintains the order of the original ARRAY,
keeping the first unique value it encounters while removing the rest.

=item B<interpolate>(TEXT [, \HASH])

Interpolates a HASH of values into a block of TEXT and returns the modified text.

Values that are to be replaced are represented in the text as '${KEY}' where KEY is a key in the HASH.
If the given HASH does not have the KEY, that portion of text is left unchanged.

For example:

   interpolate('this is a ${test}', { test => 'clusterfoo' })

will return the string, "this is a clusterfoo".

If no HASH is given, %ENV is used.

=item B<match>(REGEX, ARRAY|ARRAYREF))

Searches the ARRAY for a match to REGEX.
Returns '1' of a match is found and '0' if not.

=item B<indent>(INDENT, TEXT)

Indents a block of TEXT.
If INDENT is a string, that string will be prepended to each line.
If INDENT is numeric, that number of spaces will be prepended to each line.

Returns the indented block of text.

=item B<undent>(TEXT)

Removes the indent from a block of TEXT by finding the smallest indent
and removing that number of spaces from the beginning of each line.
Tabs are translated to be 4 spaces.

=item B<trim>(STRING)

Trims leading and trailing whitespace from STRING.

=back

=head1 DEPENDENCIES

=head2 Core Perl Modules

Cwd(3pm),
Data::Dumper(3pm),
English(3pm),
FindBin(3pm),
Storable(3pm)

=head2 iTools Libraries

iTools::Term::ANSI(3pm),
iTools::System(3pm)

=cut
