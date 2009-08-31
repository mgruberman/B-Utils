package B::Utils;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

use B qw(main_start main_root walksymtable class);

my (%starts, %roots, @anon_subs);

our @bad_stashes = qw(B Carp Exporter warnings Cwd Config CORE blib strict DynaLoader vars XSLoader AutoLoader base);

{ my $_subsdone=0;
sub _init { # To ensure runtimeness.
    return if $_subsdone;
    %starts = ( 'main' =>  main_start() );
    %roots  = ( 'main' =>  main_root()  );
    walksymtable(\%main::, 
                '_push_starts', 
                sub { 
                    return if scalar grep {$_[0] eq $_."::"} @bad_stashes;   
                    1;
                }, # Do not eat our own children!
                '');
    push @anon_subs, { root => $_->ROOT, start => $_->START} 
        for grep { class($_) eq "CV" } B::main_cv->PADLIST->ARRAY->ARRAY;
    $_subsdone=1;
}
}

=head1 NAME

B::Utils - Helper functions for op tree manipulation

=head1 SYNOPSIS

  use B::Utils;

=head1 DESCRIPTION

=head1 FUNCTIONS

=over 3

=item C<all_starts>

=item C<all_roots>

Returns a hash of all of the starting ops or root ops of optrees, keyed
to subroutine name; the optree for main program is simply keyed to "main". 

B<Note>: Certain "dangerous" stashes are not scanned for subroutines: 
the list of such stashes can be found in C<@B::Utils::bad_stashes>. Feel
free to examine and/or modify this to suit your needs. The intention is
that a simple program which uses no modules other than C<B> and
C<B::Utils> would show no addition symbols.

This does B<not> return the details of ops in anonymous subroutines
compiled at compile time. For instance, given 

    $a = sub { ... };

the subroutine will not appear in the hash. This is just as well, since
they're anonymous... If you want to get at them, use...

=item C<anon_subs()>

This returns an array of hash references. Each element has the keys
"start" and "root". These are the starting and root ops of all of
the anonymous subroutines in the program.

=cut

sub all_starts { _init(); return %starts; }
sub all_roots  { _init(); return %roots; }
sub anon_subs { _init(); return @anon_subs }

sub B::GV::_push_starts {
    my $name = $_[0]->STASH->NAME."::".$_[0]->SAFENAME;
    return unless ${$_[0]->CV};
    my $cv = $_[0]->CV;

    if ($cv->PADLIST->can("ARRAY") and $cv->PADLIST->ARRAY and $cv->PADLIST->ARRAY->can("ARRAY")) {
        push @anon_subs, { root => $_->ROOT, start => $_->START} 
            for grep { class($_) eq "CV" } $cv->PADLIST->ARRAY->ARRAY;
    }
    return unless ${$cv->START} and ${$cv->ROOT};
    $starts{$name} = $cv->START;
    $roots{$name} = $cv->ROOT;
};

sub B::SPECIAL::_push_starts{}

=item C<< $op->oldname >>

Returns the name of the op, even if it is currently optimized to null.
This helps you understand the stucture of the op tree.

=cut

sub B::OP::oldname {
    return substr(B::ppname($_[0]->targ),3) if $_[0]->name eq "null" and $_[0]->targ;
    return $_[0]->name;
}

=item C<< $op->kids >>

Returns an array of all this op's non-null children.

=cut

sub B::OP::kids {
    my $op = shift;
    my @rv;
    push @rv, $op->first if $op->can("first") and $op->first and ${$op->first};
    push @rv, $op->last if $op->can("last") and $op->last and ${$op->last};
    push @rv, $op->other if $op->can("other") and $op->other and ${$op->other};
    if (class($op) eq "LISTOP") { 
        $op = $op->first;
        push @rv, $op while $op->can("sibling") and $op = $op->sibling and $$op;
    }
    return @rv;
}

=item C<< $op->parent >>

Returns the parent node in the op tree, if possible. Currently "possible" means
"if the tree has already been optimized"; that is, if we're during a C<CHECK>
block. (and hence, if we have valid C<next> pointers.)

In the future, it may be possible to search for the parent before we have the
C<next> pointers in place, but it'll take me a while to figure out how to do
that.

=cut

# This is probably the most efficient algorithm for finding the parent given the
# next node in execution order and the children of an op. You'll be glad to hear
# that it doesn't do a full search of the tree from the root, but it searches
# ever-higher subtrees using a breathtaking double recursion. It works on the
# principle that the C<next> pointer will always point to an op further northeast
# on the tree, and hence will be heading upwards toward the parent.

sub B::OP::parent {
    my $target = shift;
    die "I'm not sure how to do this yet. I'm sure there is a way. If you know, please email me."
        if (!$op->seq);
    my (%deadend, $search);
    $search = sub {
        my $node = shift || return undef;

        # Go up a level if we've got stuck, and search (for the same
        # $target) from a higher vantage point.
        return $search->($node->parent) if exists $deadend{$node};

        # Test the immediate children
        return $node if scalar grep {$_ == $target} $node->kids;

        # Recurse
        my $x;
        defined($x = $search->($_)) and return $x for $node->kids};

        # Not in this subtree.
        $deadend{$node}++;
        return undef;
   };
   my $result;
   $result = $search->($start) and return $result while $start = $start->next;
   return $search->($start);
}

=item C<< $op->previous >>

Like C<< $op->next >>, but not quite.

=cut

sub B::OP::previous {
    my $target = shift;
    my $start = $target;
    my (%deadend, $search);
    $search = sub {
        my $node = shift || die;
        return $search->(find_parent($node)) if exists $deadend{$node};
        return $node if $node->{next}==$target;
        # Recurse
        my $x;
        ($_->next == $target and return $_) for $node->kids;
        defined($x = $search->($_)) and return $x for $node->{kids};
 
        # Not in this subtree.
        $deadend{$node}++;
        return undef;
   };
   my $result;
   $result = $search->($start) and return $result;
        while $start = $start->next;
}

1;
=head2 EXPORT

None by default.

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 TODO

I need to add more Fun Things, and possibly clean up some parts where
the (previous/parent) algorithm has catastrophic cases, but it's more
important to get this out right now than get it right.

=head1 SEE ALSO

L<B>, L<B::Generate>.

=cut
