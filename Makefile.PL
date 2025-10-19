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
    EXE_FILES => ['bin/normalo'],

    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);

sub MY::postamble {
    return <<'MAKE_FRAG';
format:
	perltidy Makefile.PL $(TO_INST_PM) $(EXE_FILES) $(TEST_FILES)

critic:
	perlcritic Makefile.PL $(TO_INST_PM) $(EXE_FILES) $(TEST_FILES)

MAKE_FRAG
}

# Restore .direnv symlinks
END {
    while (my ($path, $target) = each %direnv_symlinks) {
        symlink($target, $path) or warn "Could not restore symlink $path: $!";
    }
}
