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
is_deeply(\@lines,
          [8, 15, 17, 17, 18, 20, 27, 28, 30, 33
           # 35,
          ],
          'walkoptree_simple lines of ' . __FILE__);

# For testing following if/else in code.
if (@lines) {
  ok(1);     # We had a bug in not getting this line number once
} else {
  ok(0);
}

done_testing();
__END__
diag join(', ', @lines), "\n";
