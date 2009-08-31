use lib 'inc';
require ExtUtils::Depends;

my $pkg = ExtUtils::Depends->new('B::Utils');

$pkg->install('BUtils.h');

$pkg->add_xs("Utils.xs", "OP.xs");

$pkg->add_pm( 'lib/B/Utils.pm' => '$(INST_LIB)/B/Utils.pm',
              'lib/B/Utils/OP.pm' => '$(INST_LIB)/B/Utils/OP.pm' );

$pkg->add_typemaps("typemap");

$pkg->save_config('build/IFiles.pm');

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'B::Utils',
    VERSION_FROM  => 'lib/B/Utils.pm',
    PREREQ_PM     => {},
    ABSTRACT_FROM => 'lib/B/Utils.pm',
    AUTHOR        => 'Joshua b. Jore <jjore@cpan.org>',
    LICENSE       => 'perl',
    test          => { TESTS => 't/*.t t/*/*.t' },
    $pkg->get_makefile_vars,
);
