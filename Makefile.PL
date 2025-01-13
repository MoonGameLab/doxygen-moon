use 5.8.8;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME            => 'Doxygen::Filter::Moon',
    VERSION_FROM    => 'lib/Doxygen/Filter/Moon.pm', # finds $VERSION
    ABSTRACT        => 'Methods for pre-filtering Moonscript code for Doxygen',
    PREREQ_PM       => {
            'Log::Log4perl'             => 1.46,
            'Test::More'                => 0.98,
            'Test::Output'              => 1.03,
    },
    AUTHOR          => 'Tourahi Amine',
    EXE_FILES       => ['bin/moon2dox'],
);
