use 5.040000;
use strict;
use warnings;

use App::Normalo;
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

# Call App::Normalo::main with @args, capturing its exit code and output.
sub run_normalo {
    my (@args) = @_;
    my ($out, $err) = (q{}, q{});
    open my $out_fh, '>', \$out or die "Cannot capture output: $!";
    open my $err_fh, '>', \$err or die "Cannot capture errors: $!";
    my $code = App::Normalo::main(\@args, progname => 'normalo', out => $out_fh, err => $err_fh);
    close $out_fh or die "Cannot close output capture: $!";
    close $err_fh or die "Cannot close error capture: $!";
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

subtest 'bin/normalo uses the script name and STDOUT' => sub {
    my $out = qx{"$^X" -Ilib bin/normalo --version};
    is($?, 0, 'exits 0');
    is($out, "normalo version $App::Normalo::VERSION\n", 'prints version');
};

subtest 'unknown option' => sub {
    my ($code, $out, $err) = run_normalo('--bogus');
    is($code, 1, 'exits 1');
    is($out, q{}, 'prints nothing to STDOUT');
    like($err, qr/\Anormalo:\ Unknown\ option:\ bogus$/smx, 'reports the unknown option');
    like($err, qr/Try\ 'normalo\ --help'/smx, 'suggests --help');
};

subtest 'missing file operand' => sub {
    my ($code, undef, $err) = run_normalo();
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
    is_deeply(entries($dir), ['dash-file.txt'], 'file renamed');
};

subtest 'directory is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $sub = catfile($dir, 'Sub Dir');
    mkdir $sub or die "Cannot create $sub: $!";
    my ($code, undef, $err) = run_normalo($sub);
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ .*\ is\ not\ a\ regular\ file$/smx, 'reports non-regular file');
    is_deeply(entries($dir), ['Sub Dir'], 'directory not renamed');
};

subtest 'missing file is rejected' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my ($code, undef, $err) = run_normalo(catfile($dir, 'No Such File.txt'));
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ .*\ is\ not\ a\ regular\ file$/smx, 'reports non-regular file');
};

subtest 'existing target is not clobbered' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    touch($dir, 'my-file.txt');
    my ($code, undef, $err) = run_normalo($path);
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ cannot\ rename\ .*:\ target\ already\ exists$/smx, 'reports collision');
    is_deeply(entries($dir), [ 'My File.txt', 'my-file.txt' ], 'neither file renamed');
};

subtest 'name that is not valid UTF-8 (#7)' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = eval { touch($dir, "\xe9t\xe9 File.txt") };
    plan skip_all => 'filesystem rejects non-UTF-8 names' if !defined $path;
    my $other = touch($dir, 'Other File.txt');
    my ($code, undef, $err) = run_normalo($path, $other);
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ cannot\ rename\ .*:\ name\ is\ not\ valid\ UTF-8$/smx, 'reports the name');
    is_deeply(entries($dir), [ 'other-file.txt', "\xe9t\xe9 File.txt" ], 'file left alone, others renamed');
};

subtest 'dangling symlink at the target is not clobbered (#10)' => sub {
    plan skip_all => 'symlinks not supported' if !eval { symlink q{}, q{}; 1 };
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    my $target = catfile($dir, 'my-file.txt');
    symlink 'nowhere', $target or die "Cannot create $target: $!";
    my ($code, undef, $err) = run_normalo($path);
    is($code, 1, 'exits 1');
    like($err, qr/target\ already\ exists$/smx, 'reports collision');
    ok(-l $target, 'symlink left in place');
    ok(-e $path, 'file not renamed');
};

subtest 'case-only rename where the target is the same file (#2)' => sub {

    # A case-insensitive filesystem reports the source itself at the target;
    # two hard links whose names differ only in case look the same
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'File.txt');
    link $path, catfile($dir, 'file.txt') or plan skip_all => "hard links not supported: $!";
    my ($code, $out, $err) = run_normalo($path);
    is($code, 0, 'exits 0');
    is($out . $err, q{}, 'prints nothing');
    is_deeply(entries($dir), ['file.txt'], 'renamed to the lowercase name');
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
    my @paths = map { touch($dir, $_) } ('One File.txt', 'Two File.txt', 'Three File.txt');
    touch($dir, 'two-file.txt');
    my $missing = catfile($dir, 'No Such File.txt');
    my ($code, undef, $err) = run_normalo($paths[0], $missing, @paths[ 1, 2 ]);
    is($code, 1, 'exits 1');
    is_deeply(entries($dir), [ 'Two File.txt', 'one-file.txt', 'three-file.txt', 'two-file.txt' ],
        'files after the failures are still renamed');
    my @lines = split /\n/smx, $err;
    is(scalar @lines, 2, 'reports each failure once');
    like($lines[0], qr/is\ not\ a\ regular\ file$/smx, 'reports the missing file');
    like($lines[1], qr/target\ already\ exists$/smx, 'reports the collision');
};

subtest 'failed rename (#8)' => sub {
    plan skip_all => 'running as root ignores directory permissions' if $> == 0;
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    chmod 0555, $dir or die "Cannot chmod $dir: $!";

    my ($code, $err);
    my $died = !eval { ($code, undef, $err) = run_normalo($path); 1 };
    chmod 0755, $dir or die "Cannot chmod $dir: $!";

    is_deeply(entries($dir), ['My File.txt'], 'file not renamed');
    ok(!$died, 'does not die');
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ failed\ to\ rename\ .*:\ .+$/smx, 'reports the failure');
};

done_testing();
