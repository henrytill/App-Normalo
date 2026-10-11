use 5.040000;
use strict;
use warnings;

use Errno qw(EPERM);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

# Replace link() before App::Normalo is compiled, so that each test can make
# it misbehave. $before_link runs first; $fail_link, if set, makes it fail
# with that errno without linking.
our ($before_link, $fail_link);

BEGIN {
    *CORE::GLOBAL::link = sub {
        my ($old, $new) = @_;
        $before_link->($old, $new) if $before_link;
        if ($fail_link) {
            $! = $fail_link;    ## no critic (Variables::RequireLocalizedPunctuationVars)
            return 0;
        }
        return CORE::link($old, $new);
    };
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
    local $before_link = sub { write_file($dir, 'my-file.txt', 'target') };

    my $error = App::Normalo::rename_path($path);
    like($error, qr/target\ already\ exists$/smx, 'reports collision');
    is(slurp($target), 'target', 'target keeps its contents');
    is(slurp($path), 'source', 'source left in place');
};

subtest 'falls back to rename without hard links' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = write_file($dir, 'My File.txt', 'source');
    local $fail_link = EPERM;

    is(App::Normalo::rename_path($path), undef, 'succeeds');
    ok(!-e $path, 'old name gone');
    is(slurp(catfile($dir, 'my-file.txt')), 'source', 'renamed');
};

done_testing();
