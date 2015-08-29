package Hydra::Plugin::GitInput;

use strict;
use parent 'Hydra::Plugin';
use Digest::SHA qw(sha256_hex);
use File::Path;
use Hydra::Helper::Nix;
use Nix::Store;
use Encode;

sub supportedInputTypes {
    my ($self, $inputTypes) = @_;
    $inputTypes->{'git'} = 'Git checkout';
}

sub _isHash {
    my ($rev) = @_;
    return length($rev) == 40 && $rev =~ /^[0-9a-f]+$/;
}

# Return a list of refs available in a remote repository
sub _getRefs {
    my ($self, $uri, $refPattern) = @_;
    my $refs = grab(cmd => ["git", "ls-remote", $uri, $refPattern]);
    die "error fetching remote refs: $refPattern from: $uri\n" unless $refs =~ /[0-9a-fA-F]+/;
    print "DEBUG: getRefs with $refs\n";
    return split(/\n/, $refs);
}

# Clone or update a repository into our SCM cache.
sub _cloneRepo {
    my ($self, $uri, $revision, $deepClone) = @_;

    my $cacheDir = getSCMCacheDir . "/git";
    mkpath($cacheDir);
    my $clonePath = $cacheDir . "/" . sha256_hex($uri);
    print "DEBUG: here with $self, $uri, $revision, $deepClone\n";

    my $res;
    if (! -d $clonePath) {
        # Clone everything and add remote
        $res = run(cmd => ["git", "init", $clonePath]);
        $res = run(cmd => ["git", "remote", "add", "origin", "--", $uri], dir => $clonePath) unless $res->{status};
        die "error creating git repo in `$clonePath':\n$res->{stderr}" if $res->{status};
    }

    # Attempt to only fetch the revision we need, if that fails then fetch all the things.
    $res = run(cmd => ["git", "fetch", "-fu", "origin", "+$revision"], dir => $clonePath, timeout => 600);
    $res = run(cmd => ["git", "fetch", "-fu", "origin"], dir => $clonePath, timeout => 600) if $res->{status};
    die "error fetching latest change from git repo at `$uri':\n$res->{stderr}" if $res->{status};

    # If deepClone is defined, then we look at the content of the repository
    # to determine if this is a top-git revision.
    if (defined $deepClone) {

        # Is the target revision a topgit revision?
        $res = run(cmd => ["git", "ls-tree", "-r", "$revision", ".topgit"], dir => $clonePath);

        if ($res->{stdout} ne "") {
            # Checkout the revision to look at its content.
            $res = run(cmd => ["git", "checkout", "--force", "$revision"], dir => $clonePath);
            die "error checking out Git revision '$revision' at `$uri':\n$res->{stderr}" if $res->{status};

            # This is a TopGit revsion.  Fetch all the topic revsiones so
            # that builders can run "tg patch" and similar.
            $res = run(cmd => ["tg", "remote", "--populate", "origin"], dir => $clonePath, timeout => 600);
            print STDERR "warning: `tg remote --populate origin' failed:\n$res->{stderr}" if $res->{status};
        }
    }

    return $clonePath;
}

sub _parseValue {
    my ($value) = @_;
    (my $uri, my $refPattern, my $deepClone, my $limit) = split ' ', $value;
    $refPattern = defined $refPattern ? $refPattern : "refs/heads/master";
    $limit = defined $limit ? $limit : 0;
    return ($uri, $refPattern, $deepClone, $limit);
}

sub fetchInput {
    my ($self, $type, $name, $value) = @_;

    return undef if $type ne "git";

    my ($uri, $refPattern, $deepClone, $limit) = _parseValue($value);

    my $timestamp = time;
    my $sha256;
    my $revision;
    my $storePath;
    my $ref;
    my $cachedInput;

    my @refs = $self->_getRefs($uri, $refPattern);
    my $refCount = @refs;
    my $clonePath;
    print "DEBUG: fetchInput with $uri, $refPattern, $deepClone, $limit and refs @refs\n";
    my $remote;

    foreach $remote (@refs) {
      ($revision, $ref) = split(/\s+/, $remote);
      ($cachedInput) = $self->{db}->resultset('CachedGitRefInputs')->search(
        {uri => $uri, ref => $ref, revision => $revision},
        {rows => 1});
      last if (!defined $cachedInput || !isValidPath($cachedInput->storepath));
    }

    print "DEBUG: fetchInput2 with $revision $refCount\n";
    if (defined $cachedInput && isValidPath($cachedInput->storepath)) {
        $storePath = $cachedInput->storepath;
        $sha256 = $cachedInput->sha256hash;
        $revision = $cachedInput->revision;
    } else {
        $clonePath = $self->_cloneRepo($uri, $revision, $deepClone);
        # Then download this revision into the store.
        print STDERR "checking out Git revision $revision from $uri\n";
        $ENV{"NIX_HASH_ALGO"} = "sha256";
        $ENV{"PRINT_PATH"} = "1";
        $ENV{"NIX_PREFETCH_GIT_LEAVE_DOT_GIT"} = "0";
        $ENV{"NIX_PREFETCH_GIT_DEEP_CLONE"} = "";

        if (defined $deepClone) {
            # Checked out code often wants to be able to run `git
            # describe', e.g., code that uses Gnulib's `git-version-gen'
            # script.  Thus, we leave `.git' in there.
            $ENV{"NIX_PREFETCH_GIT_LEAVE_DOT_GIT"} = "1";

            # Ask for a "deep clone" to allow "git describe" and similar
            # tools to work.  See
            # http://thread.gmane.org/gmane.linux.distributions.nixos/3569
            # for a discussion.
            $ENV{"NIX_PREFETCH_GIT_DEEP_CLONE"} = "1";
        }

        # FIXME: Don't use nix-prefetch-git.
        ($sha256, $storePath) = split ' ', grab(cmd => ["nix-prefetch-git", $clonePath, $revision], chomp => 1);

        txn_do($self->{db}, sub {
            $self->{db}->resultset('CachedGitInputs')->update_or_create(
                { uri => $uri
                , ref => $ref
                , revision => $revision
                , sha256hash => $sha256
                , storepath => $storePath
                });
            });
    }

    # For convenience in producing readable version names, pass the
    # number of commits in the history of this revision (‘revCount’)
    # the output of git-describe (‘gitTag’), and the abbreviated
    # revision (‘shortRev’).
    my $revCount = scalar(split '\n', grab(cmd => ["git", "rev-list", "$revision"], dir => $clonePath));
    my $gitTag = grab(cmd => ["git", "describe", "--always", "$revision"], dir => $clonePath, chomp => 1);
    my $shortRev = grab(cmd => ["git", "rev-parse", "--short", "$revision"], dir => $clonePath, chomp => 1);

    return
        { uri => $uri
        , storePath => $storePath
        , sha256hash => $sha256
        , revision => $revision
        , revCount => int($revCount)
        , gitTag => $gitTag
        , shortRev => $shortRev
        };
}

sub getCommits {
    my ($self, $type, $value, $rev1, $rev2) = @_;
    return [] if $type ne "git";

    return [] unless $rev1 =~ /^[0-9a-f]+$/;
    return [] unless $rev2 =~ /^[0-9a-f]+$/;

    my ($uri, $refPattern, $deepClone, $limit) = _parseValue($value);

    my $clonePath = getSCMCacheDir . "/git/" . sha256_hex($uri);

    my $out = grab(cmd => ["git", "log", "--pretty=format:%H%x09%an%x09%ae%x09%at", "$rev1..$rev2"], dir => $clonePath);

    my $res = [];
    foreach my $line (split /\n/, $out) {
        my ($revision, $author, $email, $date) = split "\t", $line;
        push @$res, { revision => $revision, author => decode("utf-8", $author), email => $email };
    }

    return $res;
}

1;
