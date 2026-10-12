use 5.040000;
use strict;
use warnings;

use App::Normalo;
use Cwd qw(getcwd);
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

subtest '--dry-run' => sub {
    for my $opt ('--dry-run', '-n') {
        my $dir = tempdir(CLEANUP => 1);
        my @paths = map { touch($dir, $_) } ('My File.txt', 'already-normal.txt');
        my ($code, $out, $err) = run_normalo($opt, @paths);
        is($code, 0, "$opt exits 0");
        is($out, "$paths[0] -> " . catfile($dir, 'my-file.txt') . "\n", "$opt prints only the change");
        is($err, q{}, "$opt prints nothing to STDERR");
        is_deeply(entries($dir), [ 'My File.txt', 'already-normal.txt' ], "$opt renames nothing");
    }
};

subtest '--dry-run reports a hard link differing only in case' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'File.txt');
    link $path, catfile($dir, 'file.txt') or plan skip_all => "hard links not supported: $!";
    my ($code, $out, $err) = run_normalo('--dry-run', $path);
    is($code, 1, 'exits 1, as a real run would');
    is($out, q{}, 'previews nothing');
    like($err, qr/target\ already\ exists$/smx, 'reports collision');
};

subtest '--dry-run keeps the path as given' => sub {
    my $dir = tempdir(CLEANUP => 1);
    touch($dir, 'My File.txt');
    my $cwd = getcwd();
    chdir $dir or die "Cannot chdir to $dir: $!";
    my ($code, $out) = run_normalo('--dry-run', 'My File.txt');
    chdir $cwd or die "Cannot chdir to $cwd: $!";
    is($code, 0, 'exits 0');
    is($out, "My File.txt -> my-file.txt\n", 'no ./ added to a bare name');
};

subtest '--dry-run reports what would fail' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $taken = touch($dir, 'Taken File.txt');
    touch($dir, 'taken-file.txt');
    my $path = touch($dir, 'Free File.txt');
    my ($code, $out, $err) = run_normalo('--dry-run', $taken, catfile($dir, 'No Such File.txt'), $path);
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ cannot\ rename\ .*:\ target\ already\ exists$/smx, 'reports collision');
    like($err, qr/is\ not\ a\ regular\ file$/smx, 'reports missing file');
    is($out, "$path -> " . catfile($dir, 'free-file.txt') . "\n", 'still previews the rest');
    is_deeply(entries($dir), [ 'Free File.txt', 'Taken File.txt', 'taken-file.txt' ], 'renames nothing');
};

subtest '--dry-run sees the renames before it' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my @paths = map { touch($dir, $_) } ('A B.txt', 'a_b.txt');
    my $repeat = touch($dir, 'Foo.txt');
    my $later = catfile($dir, 'foo.txt');
    my ($code, $out, $err) = run_normalo('--dry-run', @paths, $repeat, $repeat, $later);
    is($code, 1, 'exits 1, as a real run would');
    is($out, "$paths[0] -> " . catfile($dir, 'a-b.txt') . "\n$repeat -> $later\n", 'previews each rename once');
    my @lines = split /\n/smx, $err;
    is(scalar @lines, 2, 'reports two failures');
    like($lines[0], qr/target\ already\ exists$/smx, 'reports a target taken earlier in the run');
    like($lines[1], qr/is\ not\ a\ regular\ file$/smx, 'reports a path renamed earlier in the run');
    is_deeply(entries($dir), [ 'A B.txt', 'Foo.txt', 'a_b.txt' ], 'renames nothing');
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

subtest 'hard link at the target differing only in case is kept (#2)' => sub {

    # On a case-sensitive filesystem these are two names for one file, which
    # looks like a case-insensitive filesystem until the first step
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'File.txt');
    link $path, catfile($dir, 'file.txt') or plan skip_all => "hard links not supported: $!";
    my ($code, undef, $err) = run_normalo($path);
    is($code, 1, 'exits 1');
    like($err, qr/\Anormalo:\ cannot\ rename\ .*:\ target\ already\ exists$/smx, 'reports collision');
    is_deeply(entries($dir), [ 'File.txt', 'file.txt' ], 'both names kept, no temporary name left');
};

subtest 'name given in another case than the one stored' => sub {

    # A case-insensitive filesystem finds FOO.TXT as foo.txt, which is
    # already normal. Fake that here, where same_file() is all that differs.
    my $dir = tempdir(CLEANUP => 1);
    touch($dir, 'foo.txt');
    no warnings 'redefine';
    local *App::Normalo::same_file = sub { 1 };
    ok(App::Normalo::is_case_change(catfile($dir, 'FOO.TXT'), catfile($dir, 'foo.txt')), 'is a case change');
};

subtest 'case change in a directory that cannot be read' => sub {
    plan skip_all => 'running as root ignores directory permissions' if $> == 0;
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'File.txt');
    no warnings 'redefine';
    local *App::Normalo::same_file = sub { 1 };
    chmod 0300, $dir or die "Cannot chmod $dir: $!";
    my $single = App::Normalo::is_case_change($path, catfile($dir, 'file.txt'));
    chmod 0700, $dir or die "Cannot chmod $dir: $!";
    ok($single, 'a file with one link is a case change');

    link $path, catfile($dir, 'Other.txt') or plan skip_all => "hard links not supported: $!";
    chmod 0300, $dir or die "Cannot chmod $dir: $!";
    my $linked = App::Normalo::is_case_change($path, catfile($dir, 'file.txt'));
    chmod 0700, $dir or die "Cannot chmod $dir: $!";
    ok(!$linked, 'a file with more links might be a hard link, so is not');
};

subtest 'hard link at the normalized name is kept' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $path = touch($dir, 'My File.txt');
    link $path, catfile($dir, 'my-file.txt') or plan skip_all => "hard links not supported: $!";
    my ($code, undef, $err) = run_normalo($path);
    is($code, 1, 'exits 1');
    like($err, qr/target\ already\ exists$/smx, 'reports collision');
    is_deeply(entries($dir), [ 'My File.txt', 'my-file.txt' ], 'both names kept');
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
