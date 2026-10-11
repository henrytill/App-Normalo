use 5.040000;
use strict;
use warnings;

use Errno qw(EPERM);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

# Replace link() and symlink() before App::Normalo is compiled, so that a
# test can run a hook in their place
our ($link_hook, $symlink_hook);

BEGIN {
    *CORE::GLOBAL::link = sub { return $link_hook ? $link_hook->(@_) : CORE::link($_[0], $_[1]) };
    *CORE::GLOBAL::symlink =
        sub { return $symlink_hook ? $symlink_hook->(@_) : CORE::symlink($_[0], $_[1]) };
}

use App::Normalo;

# Create a file named $name in $dir containing $content and return its path.
sub write_file {
    my ($dir, $name, $content) = @_;
    my $path = catfile($dir, $name);
    open my $fh, '>', $path or die "Cannot create $path: $!";
    print {$fh} $content or die "Cannot write $path: $!";
    close $fh or die "Cannot close $path: $!";
    return $path;
}

# Return the sorted names of the entries in $dir.
sub entries {
    my ($dir) = @_;
    opendir my $dh, $dir or die "Cannot open $dir: $!";
    my @names = sort grep { !/\A[.][.]?\z/smx } readdir $dh;
    closedir $dh or die "Cannot close $dir: $!";
    return \@names;
}

# Return the contents of the file at $path.
sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot open $path: $!";
    my $content = do { local $/ = undef; <$fh> };
    close $fh or die "Cannot close $path: $!";
    return $content;
}

subtest 'target created after any check is not clobbered (#10)' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'My File.txt', 'source');
    my $target = catfile($dir, 'my-file.txt');
    local $link_hook = sub {
        write_file($dir, 'my-file.txt', 'target');
        return CORE::link($_[0], $_[1]);
    };

    my $error = App::Normalo::rename_path($path);
    like($error, qr/target\ already\ exists$/smx, 'reports collision');
    is(slurp($target), 'target', 'target keeps its contents');
    is(slurp($path), 'source', 'source left in place');
};

subtest 'falls back to rename without hard links' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'My File.txt', 'source');
    local $link_hook = sub {
        $! = EPERM;    ## no critic (Variables::RequireLocalizedPunctuationVars)
        return 0;
    };

    is(App::Normalo::rename_path($path), undef, 'succeeds');
    ok(!-e $path, 'old name gone');
    is(slurp(catfile($dir, 'my-file.txt')), 'source', 'renamed');
};

subtest 'target created before a symlink is moved is not clobbered (#10)' => sub {
    plan skip_all => 'symlinks not supported' if !eval { CORE::symlink(q{}, q{}); 1 };
    my $dir = tempdir(CLEANUP => 1);
    write_file($dir, 'Target File.txt', 'source');
    my $path = catfile($dir, 'Link Name');
    CORE::symlink('Target File.txt', $path) or die "Cannot create $path: $!";
    my $new_path = catfile($dir, 'link-name');
    local $symlink_hook = sub {
        write_file($dir, 'link-name', 'target');
        return CORE::symlink($_[0], $_[1]);
    };

    my $error = App::Normalo::rename_path($path);
    like($error, qr/target\ already\ exists$/smx, 'reports collision');
    ok(!-l $new_path, 'target is not replaced by the symlink');
    is(slurp($new_path), 'target', 'target keeps its contents');
    ok(-l $path, 'symlink left in place');
};

subtest 'dangling symlink at the target is not clobbered without hard links (#10)' => sub {
    plan skip_all => 'symlinks not supported' if !eval { CORE::symlink(q{}, q{}); 1 };
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'My File.txt', 'source');
    my $target = catfile($dir, 'my-file.txt');
    CORE::symlink('nowhere', $target) or die "Cannot create $target: $!";
    local $link_hook = sub {
        $! = EPERM;    ## no critic (Variables::RequireLocalizedPunctuationVars)
        return 0;
    };

    like(App::Normalo::rename_path($path), qr/target\ already\ exists$/smx, 'reports collision');
    ok(-l $target, 'symlink left in place');
    is(slurp($path), 'source', 'source left in place');
};

subtest 'hard link differing only in case is kept without link() (#2)' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'File.txt', 'source');
    CORE::link($path, catfile($dir, 'file.txt')) or plan skip_all => "hard links not supported: $!";
    local $link_hook = sub {
        $! = EPERM;    ## no critic (Variables::RequireLocalizedPunctuationVars)
        return 0;
    };

    like(App::Normalo::rename_path($path), qr/target\ already\ exists$/smx, 'reports collision');
    is_deeply(entries($dir), [ 'File.txt', 'file.txt' ], 'both names kept, no temporary name left');
};

subtest 'case-only rename through a temporary name (#2)' => sub {

    # On a case-insensitive filesystem the old name is the only entry, so
    # $new_path doesn't exist once it's been renamed to the temporary name
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'File.txt', 'source');
    my $new_path = catfile($dir, 'file.txt');

    is(App::Normalo::rename_case($path, $new_path), undef, 'succeeds');
    opendir my $dh, $dir or die "Cannot open $dir: $!";
    my @names = sort grep { !/\A[.][.]?\z/smx } readdir $dh;
    closedir $dh or die "Cannot close $dir: $!";
    is_deeply(\@names, ['file.txt'], 'renamed, no temporary name left');
    is(slurp($new_path), 'source', 'contents kept');
};

done_testing();
