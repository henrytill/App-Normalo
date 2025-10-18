use 5.040001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'App::Normalo',
    VERSION_FROM      => 'lib/App/Normalo.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/App/Normalo.pm', # retrieve abstract from module
    AUTHOR            => 'Henry Till <ht@>',
    EXE_FILES         => ['bin/normalo'],
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
