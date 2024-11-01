package Portia::Repository;
use base qw( iTools::Core::Accessor HashRef::Maskable );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging only

use iTools::File qw( readfile writefile );
use iTools::System qw( nofatal mkdir pushdir popdir system );
use iTools::Term::ANSI qw( color );
use iTools::URI;
use iTools::Verbosity qw( verbosity vprint vtmp );
use LWP::Simple;
use Portia::Package;
use Portia::Sources;
use Portia::Tools qw( indent match );

use strict;
use warnings;

# === Constructor and Construtor-like Methods ===============================
# --- new, blank object ---
sub new {
	my ($self, %args) = (shift->mhash, @_);

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		for (lc $key) {
			if (m/^(?:repo|name)/) { $self->rname($value) }
			else                   { $self->{$key} = $value }
		}
	}

	return $self;
}

# === Accessors =============================================================
sub rname { shift->_var(name => @_) }
# --- alias for rname ---
sub name  { shift->rname(@_) }

sub env {
	my $self = shift;

	# --- default values ---
	$self->{env}->{REPO_URI} ||= $self->{uri};

	# --- no params, return entire hash ---
	return $self->{env} unless @_;

	# --- one param = get ---
	if (@_ == 1) {
		my $arg = shift;

		# --- not an array, return a single value ---
		return $self->{env}->{$arg}
			unless ref $arg eq 'ARRAY';

		# --- many values ---
		return map { $self->{env}->{$_} } @$arg;
	}

	# --- many params, we have a set ---
	my %params = @_;
	my @values;
	while (my ($key, $value) = each %params) {
		push @values, $self->{env}->{$key} = $value;
	}
	return @values;
}

# --- root dir of repo source (read-only) ---
sub root {
	my $self = shift;
	$self->{sync} eq 'live'
		? new iTools::URI(URI => $self->{uri})->path   # live repo
		: Portia::Sources->root() ."/". $self->rname;  # sync'ed repo
}

# --- object shortcuts ---
sub options { load iTools::Script::Options }

# === General Methods =======================================================
# === Public Methods ========================================================
# --- show repository config ---
sub dumpConfig {
	my $self = shift;
	my $text = '';

	$text .= "$self->{name} : $self->{description}\n";
	foreach my $key (sort keys %$self) {
		next if $key =~ /^(?:_|\.|name)/;

		#my $value = ref $self->{$key} ? join ' ', @{$self->{$key}} : $self->{$key};
		my $value = $self->{$key};
		if (ref $self->{$key} eq 'ARRAY') {
			$value = join ' ', @{$self->{$key}};
		} elsif (ref $self->{$key} eq 'HASH') {
			my $delim = "\n   ";
			$value = $delim . join $delim, map {
				$_ .'='. (defined $self->{$key}->{$_} ? $self->{$key}->{$_} : 'undef')
			} keys %{$self->{$key}};
		}

		$text .= indent(3, sprintf "%-11s : %s\n", $key, $value)
			if $value;
	}
	return $text;
}

# === Repository Synchronization ============================================
# --- update repo from its source ---
sub sync {
	my $self = shift;

	# --- sync repo based on sync type ---

	# --- live repository ---
	if ($self->{sync} eq 'live') {
		vprint 1, ">no sync required (live repository)\n";
	}
	# --- full sync ---
	elsif ($self->{sync} eq 'full') {
		vprint 1, ">full sync\n";
		vprint 2, ">using URI $self->{uri}\n";
		$self->syncFull;
	}
	# --- sparse sync ---
	#! Not sure what sparse's purpose is. Can't find where a sync'ed repo with
	#! only the .list file is used for anything. We certainly can't search it.
	elsif ($self->{sync} eq 'sparse') {
		vprint 1, ">sparse sync\n";
		vprint 2, ">using URI $self->{uri}\n";
		$self->options->{deep} ? $self->syncDeep : $self->syncList;
	}
	# --- deep sync ---
	elsif ($self->{sync} eq 'deep') {
		vprint 1, ">deep sync\n";
		vprint 2, ">using URI $self->{uri}\n";
		$self->syncDeep;
	}

	else {
		vprint 1, ">". color("y", "could not sync $self->{name}, unknown sync type '$self->{sync}'") ."\n";
	}
}

# --- do a full sync ---
sub syncFull {
	my $self = shift;

	# --- parse the URI ---
	my $uri = new iTools::URI(URI => "$self->{uri}/packages");

	# --- create the local sources root directory ---
	my $root = $self->root ."/packages";
	mkdir $root unless -d $root;
	pushdir $root;

	# --- generate command based on scheme ---
	my $cmd = "rsync -a". (verbosity >= 4 ? 'v ' : ' ') ." --delete --exclude '*/.tgz' ";  # default is rsync
	# --- rsync native, via ssh or local filesystem ---
	if    ($uri->scheme eq 'rsync') { $cmd .= $uri->host .":". $uri->path ."/* ."; } #! TODO: add username
	elsif ($uri->scheme eq 'ssh')   { $cmd .= $uri->host .":". $uri->path ."/* ."; } #! TODO: add username
	elsif ($uri->scheme eq 'file')  { $cmd .= $uri->path ."/* ."; }

	# --- otherwise wget a tarball ---
	else {
		$cmd = '';  # clear this so system won't run later

		# --- get the tarball ---
		my $content = get $uri->uri ."/.tgz";
		last unless $content;

		# --- remove everything ---
		system "rm -rf ../packages/* ../packages/.list ../packages/.tgz";

		# --- write and unpack the tarball ---
		writefile ".tgz", $content;
		system "
			$ENV{TAR} x". (verbosity >= 4 ? 'v' : '') ."zf .tgz
			rm -f .tgz
		";
	}

	# --- execute the command, ensure no fatal errors ---
	#! TODO: use a capture for this for cleaner warnings and output
	nofatal { system $cmd; }
		if $cmd;

	popdir;

	#! TODO: return status on failure
}

# --- sync only the .list file ---
sub syncList {
	my $self = shift;
	$self->_syncFile('.list');

	# --- load the package list ---
	my $listfile = $self->root ."/packages/.list";
	return unless -r $listfile;
	$self->{'.list'} = [ grep { $_ } split /\s/, readfile($listfile) ];
}

# --- sync a package via its tarball ---
sub syncPackage {
	my ($self, $package) = @_;
	my $root = $self->root ."/packages/". $package;

	# --- get the package tarball ---
	$self->_syncFile("$package/.tgz");
	return unless -e "$root/.tgz";

	# --- unpack the tarball ---
	pushdir $root;
	system "$ENV{TAR} x". (verbosity >= 4 ? 'v' : '') ."zf .tgz; rm .tgz";
	popdir;
}

# --- sync everything one package at a time ---
sub syncDeep {
	my $self = shift;

	# --- create the local sources root directory ---
	my $root = $self->root;
	mkdir $root unless -d $root;
	pushdir $root;
	# --- cleanup ---
	system "rm -rf packages/* packages/.list packages/.tgz";

	$self->syncList;
	foreach my $package (@{$self->{'.list'}}) {
		$self->syncPackage($package);
	}

	popdir;
}

# --- private methods and helpers -------------------------------------------
# --- sync a single file ---
sub _syncFile {
	my ($self, $file) = @_;

	vprint 2, ">syncing file $file\n";
	# --- split the filename and path ---
	my $path = '';
	if ($file =~ m|^(.*?/)([^/]*)$|) {
		($path, $file) = ($1, $2);
	}

	# --- generate the URI ---
	my $uri = new iTools::URI(URI => "$self->{uri}/packages/$path");

	# --- create the file root directory ---
	my $root = $self->root ."/packages";
	mkdir $root unless -d $root;
	$root .= "/$path";
	vtmp sub { mkdir $root }, 0;  # keep this one quiet unless there's an error
	pushdir $root;

	# --- generate command based on scheme ---
	my $cmd = "rsync ". (verbosity >= 4 ? '-v ' : '');  # default is rsync
	for ($uri->scheme) {
		# --- rsync native, via ssh or local filesystem ---
		if    ('rsync') { $cmd .= $uri->host .":". $uri->path ."$file ."; } #! TODO: add username
		elsif ('ssh')   { $cmd .= $uri->host .":". $uri->path ."$file ."; } #! TODO: add username
		elsif ('file')  { $cmd .= $uri->path ."$file ."; }

		# --- otherwise wget a tarball ---
		else {
			$cmd = '';  # clear this so system won't run later
			my $content = get $uri->uri . $file;
			if ($content) {
				system "rm -f $file";
				writefile $file, $content;
			}
		}
	}

	# --- execute the command, ensure no fatal errors ---
	#! TODO: use a capture for this for cleaner warnings and output
	#nofatal { system $cmd; };
	system $cmd if $cmd;

	popdir;

	#! TODO: return SOME status if the sync failed
}

# === Package Management ====================================================

# --- get a list (array) of packages ---
sub packageList {
	my $self = shift;

	# --- load a package list if we don't already have one ---
	unless ($self->{'.list'}) {
		my $root = $self->root ."/packages";

		# --- load the repo's .list file for sparse and deep ---
		if (
			$self->{sync} =~ /^(?:sparse|deep)$/ && -e "$root/.list"
		) {
			map { $self->{'.list'}->{$_} = 0 }
				grep { $_ } split /\s/, readfile("$root/.list");
		}

		# --- use the directory structure for full and live ---
		if ($self->{sync} =~ /^(?:live|full)$/) {
			# --- change the 'root' dir if live ---
			$root = new iTools::URI(URI => $self->{uri})->path ."/packages"
				if $self->{sync} eq 'live';

			# --- walk dirs to list packages ---
			my @packages;
			foreach my $category (_dirList($root)) {
				push @packages, map { "$category/$_" } _dirList("$root/$category");
			}
			map { $self->{'.list'}->{$_} = 0 } @packages;
		}
	}

	my @list = sort keys %{$self->{'.list'}};
	return wantarray ? @list : [ @list ];
}

# --- load all packages for the repo ---
sub loadPackages {
	my ($self, $deep) = @_;
	foreach my $pname ($self->packageList) {
		$self->loadPackage($pname);
	}
}
# --- load an individual package ---
sub loadPackage {
	my ($self, $pname) = @_;
	load Portia::Package(
		Repo => $self->name,
		Name => $pname,
	);
}

# === Query Methods =========================================================
# --- query methods ---
sub matches {
	my ($self, %params) = @_;

	while (my ($key, $value) = each %params) {
		# --- ignore undef and blank values ---
		next unless defined $value && $value ne '';

		# --- query repo's tags ---
		if (lc $key eq 'tags') {
			foreach my $query (ref $value ? @$value : $value) {
				return unless match($query, $self->{tags});
			}
		}
		elsif (lc $key eq 'name') {
			return unless $self->name eq $value;
		}
		# --- query all other keys for the repo ---
		else {
			return unless exists $self->{$key} && defined $self->{$key};
			return unless match($value, $self->{$key});
		}
	}

	# --- if we got here, we have a match ---
	return $self;
}

# === Private Helper Functions and Methods ==================================
# --- helper to get a list of dirs from a package tree ---
sub _dirList {
	my $path = shift;
	return unless -d $path;
	opendir DIRLIST, $path;
	my @dirs = grep { -d "$path/$_" && /^[^\.]/ } readdir DIRLIST;
	close DIRLIST;
	return @dirs;
}

1;
