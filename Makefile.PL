use 5.040000;
use ExtUtils::MakeMaker;

my %direnv_symlinks;

# Record and unlink .direnv symlinks
if (-d '.direnv' && !-f 'Makefile') {
    opendir(my $dh, '.direnv') or die "Cannot open .direnv: $!";
    while (my $entry = readdir($dh)) {
        next if $entry eq '.' || $entry eq '..';
        my $path = ".direnv/$entry";
        if (-l $path) {
            $direnv_symlinks{$path} = readlink($path);
            unlink($path) or warn "Could not unlink $path: $!";
        }
    }
    closedir($dh);
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME => 'App::Normalo',
    VERSION_FROM => 'lib/App/Normalo.pm',    # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM => {
        'Text::Unidecode' => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    },
    ABSTRACT_FROM => 'lib/App/Normalo.pm',    # retrieve abstract from module
    AUTHOR => 'Henry Till <henrytill@gmail.com>',
    LICENSE => 'perl_5',
    MIN_PERL_VERSION => '5.040000',
    EXE_FILES => ['bin/normalo'],
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            bugtracker => { web => 'https://github.com/henrytill/App-Normalo/issues' },
            repository => {
                type => 'git',
                url => 'https://github.com/henrytill/App-Normalo.git',
                web => 'https://github.com/henrytill/App-Normalo',
            },
        },
    },
);

# Restore .direnv symlinks
END {
    while (my ($path, $target) = each %direnv_symlinks) {
        symlink($target, $path) or warn "Could not restore symlink $path: $!";
    }
}
