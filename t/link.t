use 5.040000;
use strict;
use warnings;

use Errno qw(EPERM);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

# Replace link() before App::Normalo is compiled, so that a test can run
# $link_hook in its place
our $link_hook;

BEGIN {
    *CORE::GLOBAL::link = sub { return $link_hook ? $link_hook->(@_) : CORE::link($_[0], $_[1]) };
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

done_testing();
