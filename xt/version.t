#!perl
use strict;
use warnings;
use Test::More tests => 5;


open my $fh, '<', 'lib/B/Utils.pm'
  or die "Can't open lib/B/Utils.pm: $!";
undef $/;
my $doc = <$fh>;
close $fh;

ok( my ( $pod_version ) = $doc =~ /^=head1\s+VERSION\s+([\d._]+)/m,
    "Extract version from pod in lib/B/Utils.pm" );
ok( my ( $pm_version ) = $doc =~ /^\$VERSION\s+=\s+'([\d._]+)';/m,
    "Extract version from code in lib/B/Utils.pm" );
is( $pod_version, $pm_version, 'Documentation & $VERSION are the same' );


open $fh, '<', 'README'
  or die "Can't open README: $!";
$doc = <$fh>;
close $fh;
ok( my ( $readme_version ) = $doc =~ /^VERSION\s+([\d._]+)/m,
    "Extract version from README" );

is( $readme_version, $pm_version, 'README & $VERSION are the same' );