#!perl
use Test::More;
use lib '../../lib';
use lib '../../blib/arch/auto/B/Utils';
use B qw(class);
use B::Utils qw( all_roots walkoptree_simple);

my @lines = ();
my $callback = sub
{
  my $op = shift;
  if ('COP' eq B::class($op) and  $op->file eq __FILE__) {
    push @lines, $op->line;
  }
};

foreach my $op (values %{all_roots()}) {
  walkoptree_simple( $op, $callback );
}
my $expected = [8, 15, 17, 18, 20, 21, 27, 32, 35, 38, 39];
if ($] < 5.007) {
  $expected =  [8, 15, 17, 18, 17, 20, 21, 27, 32, 35, 38, 39];
} elsif ($] >= 5.021008) {
  $expected = [8, 15, 17, 17, 18, 20, 21, 22, 23, 24, 27, 32, 33, 35, 38, 39];
}

is_deeply(\@lines, 
          $expected,
          'walkoptree_simple lines of ' . __FILE__);

# For testing following if/else in code.
if (@lines) {
  ok(1);     # FIXME: This line isn't coming out.
} else {
  ok(0);
}

diag join(', ', @lines), "\n";
done_testing();

