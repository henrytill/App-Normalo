use 5.040000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME => 'App::Normalo',
    VERSION_FROM => 'lib/App/Normalo.pm',    # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM => {
        'Text::Unidecode' => 0,
    },
    ABSTRACT_FROM => 'lib/App/Normalo.pm',    # retrieve abstract from module
    AUTHOR => 'Henry Till <ht@>',
    EXE_FILES => ['bin/normalo'],

    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);

sub MY::postamble {
    return <<'MAKE_FRAG';
format:
	perltidy Makefile.PL $(TO_INST_PM) $(EXE_FILES) $(TEST_FILES)

MAKE_FRAG
}
