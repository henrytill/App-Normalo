use 5.040000;
use strict;
use warnings;

use App::Normalo;
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

local $0 = 'normalo';

# Call App::Normalo->run with @args, capturing its exit code and output.
sub run_normalo {
    my (@args) = @_;
    my ($out, $err) = (q{}, q{});
    open my $out_fh, '>', \$out or die "Cannot capture STDOUT: $!";
    open my $err_fh, '>', \$err or die "Cannot capture STDERR: $!";
    my $code = do {
        local *STDOUT = $out_fh;
        local *STDERR = $err_fh;
        App::Normalo->run(@args);
    };
    close $out_fh or die "Cannot close STDOUT capture: $!";
    close $err_fh or die "Cannot close STDERR capture: $!";
    return ($code, $out, $err);
}

# Create an empty file named $name in $dir and return its path.
sub touch {
    my ($dir, $name) = @_;
    my $path = catfile($dir, $name);
    open my $fh, '>', $path or die "Cannot create $path: $!";
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

subtest '--help' => sub {
    for my $opt ('--help', '-h') {
        my ($code, $out, $err) = run_normalo($opt);
        is($code, 0, "$opt exits 0");
        like($out, qr/\AUsage:\ normalo\ /smx, "$opt prints usage");
        is($err, q{}, "$opt prints nothing to STDERR");
    }
};

subtest '--version' => sub {
    for my $opt ('--version', '-v') {
        my ($code, $out, $err) = run_normalo($opt);
        is($code, 0, "$opt exits 0");
        is($out, "normalo version $App::Normalo::VERSION\n", "$opt prints version");
        is($err, q{}, "$opt prints nothing to STDERR");
    }
};

subtest 'unknown option' => sub {
    my ($code, $out, $err) = run_normalo('--bogus');
    is($code, 1, 'exits 1');
    is($out, q{}, 'prints nothing to STDOUT');
    like($err, qr/Try\ 'normalo\ --help'/smx, 'suggests --help');
};

subtest 'missing file operand' => sub {
    my ($code, $out, $err) = run_normalo();
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ missing\ file\ operand$/smx, 'reports missing operand');
};

subtest 'renames a file' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.TXT');
    my ($code, $out, $err) = run_normalo($path);
    is($code, 0, 'exits 0');
    is($out . $err, q{}, 'prints nothing');
    is_deeply(entries($dir), ['my-file.txt'], 'file renamed');
};

subtest 'renames several files' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my @paths = map { touch($dir, $_) } ('One File.txt', 'Two_File.txt');
    my ($code) = run_normalo(@paths);
    is($code, 0, 'exits 0');
    is_deeply(entries($dir), [ 'one-file.txt', 'two-file.txt' ], 'files renamed');
};

subtest 'already normalized file is left alone' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'already-normal.txt');
    my ($code, $out, $err) = run_normalo($path);
    is($code, 0, 'exits 0');
    is($out . $err, q{}, 'prints nothing');
    is_deeply(entries($dir), ['already-normal.txt'], 'file unchanged');
};

subtest 'a file after --' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, '-Dash File.txt');
    my ($code) = run_normalo('--', $path);
    is($code, 0, 'exits 0');
    is_deeply(entries($dir), ['-dash-file.txt'], 'file renamed');
};

subtest 'directory is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $sub = catfile($dir, 'Sub Dir');
    mkdir $sub or die "Cannot create $sub: $!";
    my ($code, $out, $err) = run_normalo($sub);
    is($code, 1, 'exits 1');
    like($err, qr/is\ not\ a\ regular\ file/smx, 'reports non-regular file');
    is_deeply(entries($dir), ['Sub Dir'], 'directory not renamed');
};

subtest 'missing file is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my ($code, $out, $err) = run_normalo(catfile($dir, 'No Such File.txt'));
    is($code, 1, 'exits 1');
    like($err, qr/is\ not\ a\ regular\ file/smx, 'reports non-regular file');
};

subtest 'existing target is not clobbered' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    my $target = touch($dir, 'my-file.txt');
    open my $fh, '>', $target or die "Cannot open $target: $!";
    print {$fh} "keep me\n" or die "Cannot write $target: $!";
    close $fh or die "Cannot close $target: $!";

    my ($code, $out, $err) = run_normalo($path);
    is($code, 1, 'exits 1');
    like($err, qr/target\ already\ exists/smx, 'reports collision');
    is_deeply(entries($dir), [ 'My File.txt', 'my-file.txt' ], 'neither file renamed');
    is(-s $target, length "keep me\n", 'target contents preserved');
};

subtest 'symlink is renamed, not its target' => sub {
    plan skip_all => 'symlinks not supported' if !eval { symlink q{}, q{}; 1 };
    my $dir = tempdir(CLEANUP => 1);
    touch($dir, 'Target File.txt');
    my $link = catfile($dir, 'Link Name');
    symlink 'Target File.txt', $link or die "Cannot create $link: $!";
    my ($code) = run_normalo($link);
    is($code, 0, 'exits 0');
    is_deeply(entries($dir), [ 'Target File.txt', 'link-name' ], 'only the link renamed');
    ok(-l catfile($dir, 'link-name'), 'renamed entry is still a symlink');
};

subtest 'failure partway through a batch (#1)' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my @paths = map { touch($dir, $_) } ('One.txt', 'X.txt', 'Three.txt');
    touch($dir, 'x.txt');
    my ($code) = run_normalo(@paths);
    is($code, 1, 'exits 1');

TODO: {
        local $TODO = 'run() stops at the first failure (#1)';
        is_deeply(entries($dir), [ 'X.txt', 'one.txt', 'three.txt', 'x.txt' ],
            'files after the failure are still renamed');
    }
};

subtest 'failed rename (#8)' => sub {
    plan skip_all => 'running as root ignores directory permissions' if $> == 0;
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    chmod 0555, $dir or die "Cannot chmod $dir: $!";

    my ($code, $out, $err);
    my $died = !eval { ($code, $out, $err) = run_normalo($path); 1 };
    chmod 0755, $dir or die "Cannot chmod $dir: $!";

    is_deeply(entries($dir), ['My File.txt'], 'file not renamed');

TODO: {
        local $TODO = 'run() dies instead of returning 1 (#8)';
        ok(!$died, 'does not die');
        is($code, 1, 'exits 1');
    }
};

done_testing();
