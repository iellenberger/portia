package Portia::Misc;
use base Exporter;

#! Miscellaneous functions not worth making a whole separate class for

@EXPORT_OK = qw(
	pushPack
	pushUpload
	processUpload
	reindex
);

use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use English;
use FindBin qw( $RealBin );
use iTools::URI;
use iTools::System qw( mkdir system chdir pushdir popdir command );
use iTools::Verbosity qw( vprint verbosity );
use Portia::Tools qw( indent );

use strict;
use warnings;

# === Functions for 'push' Command ==========================================

#! TODO List
#
#  * Files currently clobber each other by version.  Modify the structure of
#    packages/../../ to make VR-Platform a dir for files
#  * Allow for optional and alternate distfile pushes

# --- build a tarball ---
sub pushPack {
	my ($config, $pbuild, @files) = @_;

	# --- scrape a few vars we use often ---
	my $CP = $config->{CP};
	my $VR = $config->{VR};
	my $PVR = $config->{PVR};
	my $TAR = $config->{TAR};
	my $tardir = "$config->{PW}/tar";
	my $pkgpath = "$tardir/packages/$CP";
	my @targets;

	vprint 0, "Building $CP-$VR upload package\n";

	# --- copy tarballs if they exist ---
	my $bintarball = "$config->{PORTIA_LIB}/distfiles/$CP/$PVR.tgz";
	if (-e $bintarball) {
		vprint 1, ">adding $PVR.tgz\n";
		my $distpath = "$tardir/distfiles/$CP";
		mkdir $distpath;
		system "cp $config->{PORTIA_LIB}/distfiles/$CP/$PVR.tgz $distpath";
		push @targets, 'distfiles';
	}

	# --- copy pbuild and any additional files ---
	mkdir $pkgpath;
	system "cp $pbuild $pkgpath/$PVR.pbuild";
	vprint 1, ">adding $PVR.pbuild\n";
	push @targets, 'packages';
	if (@files) {
		vprint 1, ">copying additional files\n";
		mkdir "$pkgpath/files/$PVR";
		foreach my $file (@files) {
			vprint 1, ">adding $file\n";
			system "cp -a $file $pkgpath/files/$PVR";
		}
	}

	# --- create the upload tarball ---
	pushdir $tardir;
	my $targets =
	system "$TAR c". (verbosity >= 4 ? 'v' : '') ."zf $PVR.upload.tgz ". join(' ', @targets) .
		"; rm -rf ". join(' ', @targets);
	popdir;

	# --- return tarball name ---
	return "$tardir/$PVR.upload.tgz";
}

# --- upload the tarball to the repo ---
sub pushUpload {
	my ($config, $reponame, $tarfile) = @_;

	my $tardir = "$config->{PW}/tar";

	# --- find the push repo ---
	my $repo = findRepo Portia::Sources(
		tags  => 'push',
		sync  => 'live',
		name  => $reponame,
	);

	# --- load sources ---
	use Portia::Sources;
	my $sources = new Portia::Sources(Repo => $reponame);

	# --- make sure we have a valid repo ---
	unless ($repo) {
		my $msg = $reponame ? "source repository '$reponame' is not" : "could not find";
		vprint -2, "error: $msg a valid 'push' repository\n";
		vprint -1, "\n'push' repositories must include these settings:\n\n".
		           "   sync : live\n".
		           "   tags : push\n".
		           "   uri  : file:///some/path\n\n";
		if (exists $sources->{$reponame}) {
			vprint 1, "The requested repository is configured as follows:\n\n".
			          indent(3, $sources->{$reponame}->dumpConfig()) ."\n";
		}
		vprint -1, "See the portia(1) manual page for details\n\n";
		exit 1;
	}
	$config->selectRepo($repo);

	vprint 0, "Uploading ". ($tarfile =~ /([^\/]*)$/)[0] ." to $reponame\n";

	# --- make sure the repo has a valid URI ---
	my $uri = new iTools::URI(URI => $repo->{uri});
	my ($scheme, $repopath) = ($uri->scheme || '', $uri->path || '');

	# --- 'file' scheme ---
	if ($scheme eq 'file') {
		my $uploaddir = "$repopath/upload";
		mkdir $uploaddir;
		system "mv $tarfile $uploaddir";
		return $uri;
	}

	# --- 'rsync' scheme ---
	if ($scheme eq 'rsync') {
		system "rsync -avP $tarfile ". $uri->host .":". $uri->path ."/upload; rm $tarfile";
		return $uri;
	}

	# --- implement other schemes here ---

	# --- invalid scheme ---
	my $msg = $scheme ? "invalid sync scheme '$scheme'" : "unknown sync scheme";
	vprint -2, "error: $msg for source repository '". $repo->name ."'\n";
	vprint -1, "   URI: ". $uri->uri ."\n";
	exit 1;
}

use Cwd qw( abs_path );

# --- unpack the tarball ---
sub processUpload {
	my ($config, @tarfiles) = @_;

	vprint 0, "Processing uploads\n";

	# --- make sure we have a liast of files ---
	unless (@tarfiles) {
		vprint -2, "error: no files (uploads) specified'\n";
		exit 1;
	}

	# --- get the full path for each tarfile ---
	for (my $ii = 0; $ii < @tarfiles; $ii++) {
		my $tarfile = $tarfiles[$ii];
		unless (-e $tarfile) {
			vprint -2, "error: could not find file '$tarfile'\n";
			exit 1;
		}
		$tarfiles[$ii] = abs_path($tarfile);
	}

	# --- define the temporary root ---
	my $tmproot = "$config->{WORK_ROOT}/$PID";
	pushdir;

	# --- process each tarfile ---
	my @biglist;
	foreach my $tarfile (@tarfiles) {

		vprint 1, ">processing $tarfile ". ($tarfile =~ /([^\/]*)$/)[0] ."\n";

		# --- create the temporary root ---
		mkdir $tmproot;
		chdir $tmproot;
		# system "tar xzf $config->{PORTIA_LIB}/upload/$tarfile";
		system "tar xzf $tarfile";

		chdir "$tmproot/packages";
		my @list = command "find * -mindepth 1 -maxdepth 1 -type d";

		chdir $config->{PORTIA_LIB};
		foreach my $package (@list) {
			if (-e "$tmproot/distfiles/$package") {
				mkdir "distfiles/$package";
				system "mv $tmproot/distfiles/$package/*.tgz distfiles/$package";
			}
			if (-e "$tmproot/packages/$package") {
				mkdir "packages/$package";
				system "cp -a $tmproot/packages/$package/* packages/$package";
			}
		}

		push @biglist, @list;

		system "rm -rf $tmproot";
	}

	popdir;
	return @biglist;
}

# --- index packages and package repository ---
sub reindex {
	my ($config, @list) = @_;

	my $TAR = $config->{TAR};
	pushdir $config->{PORTIA_LIB};

	# --- generate package manifests and tarballs ---
	foreach my $package (@list) {
		chdir "$config->{PORTIA_LIB}/packages/$package";
		vprint 0, "Generating package manifest and tarball for $package\n";
		system "$RealBin/manifest -grfq -O .mf *";
		system "$TAR c". (verbosity >= 4 ? 'v' : '') ."zf .tgz * .mf";
	}

	# --- generate repository list and tarball ---
	vprint 0, "Generating repository package list and tarball\n";
	chdir "$config->{PORTIA_LIB}/packages";
	system "find * -mindepth 1 -maxdepth 1 -type d > .list";
	system "$TAR c". (verbosity >= 4 ? 'v' : '') ."zf .tgz --exclude .tgz .list *";

	popdir;
}
