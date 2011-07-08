#!perl
use 5.006;
use strict;

my $ExtUtils_Depends_required = 0.302;
eval {
	require ExtUtils::Depends;
};
if ( $@ or ExtUtils::Depends->VERSION < $ExtUtils_Depends_required ) {
	print "ExtUtils::Depends $ExtUtils_Depends_required is required to configure this module, please install it manually or upgrade your CPAN/CPANPLUS shell\n";
	exit(0);
}

my $pkg = ExtUtils::Depends->new('B::Utils');

$pkg->install('BUtils.h');

$pkg->add_xs("Utils.xs", "OP.xs");

$pkg->add_pm( 'lib/B/Utils.pm' => '$(INST_LIB)/B/Utils.pm',
              'lib/B/Utils/OP.pm' => '$(INST_LIB)/B/Utils/OP.pm' );

$pkg->add_typemaps("typemap");

$pkg->save_config('build/IFiles.pm');

use ExtUtils::MakeMaker;

WriteMakefile1(
    NAME          => 'B::Utils',
    VERSION_FROM  => 'lib/B/Utils.pm',
    PREREQ_PM     => {
        'Scalar::Util' => 0,
        'Task::Weaken' => 0,
        'Exporter'     => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'ExtUtils::CBuilder' => 0,
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::Depends' => $ExtUtils_Depends_required,
        'ExtUtils::CBuilder' => 0,
    },
    ABSTRACT_FROM => 'lib/B/Utils.pm',
    AUTHOR        => 'Josh Jore <jjore@cpan.org>',
    LICENSE       => 'perl',
    MIN_PERL_VERSION => 5.006,
    META_MERGE => {
      resources => {
        repository => 'http://github.com/jbenjore/B-Utils/tree',
      },
      keywords => ['op tree','perl internals'],
    },
    test          => { TESTS => 't/*.t t/*/*.t' },
    $pkg->get_makefile_vars,
);

sub WriteMakefile1 {
    my %params=@_;
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES}) { #and $eumm_version < 6.5503
        #Should be modified in future when EUMM will
        #correctly support BUILD_REQUIRES.
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    WriteMakefile(%params);
}
