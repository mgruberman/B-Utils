package B::Utils;

use 5.006;
use strict;
use warnings;
our @EXPORT_OK = qw(all_starts all_roots anon_subs
                    walkoptree_simple walkoptree_filtered
                    walkallops_simple walkallops_filtered
                    carp croak
                    opgrep
                   );
sub import {
  my $pack = shift;
  my @exports = @_;
  my $caller = caller;
  my %EOK = map {$_ => 1} @EXPORT_OK;
  for (@exports) {
    unless ($EOK{$_}) {
      require Carp;
      Carp::croak(qq{"$_" is not exported by the $pack module});
    }
    no strict 'refs';
    *{"$caller\::$_"} = \&{"$pack\::$_"};
  }
}

our $VERSION = '0.04';

use B qw(main_start main_root walksymtable class OPf_KIDS);

my (%starts, %roots, @anon_subs);

our @bad_stashes = qw(B Carp Exporter warnings Cwd Config CORE blib strict DynaLoader vars XSLoader AutoLoader base);

{ my $_subsdone=0;
sub _init { # To ensure runtimeness.
    return if $_subsdone;
    %starts = ( '__MAIN__' =>  main_start() );
    %roots  = ( '__MAIN__' =>  main_root()  );
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

These functions make it easier to manipulate the op tree.

=head1 FUNCTIONS

=over 3

=item C<all_starts>

=item C<all_roots>

Returns a hash of all of the starting ops or root ops of optrees, keyed
to subroutine name; the optree for main program is simply keyed to C<__MAIN__>.

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

Returns an array of all this op's non-null children, in order.

=cut

sub B::OP::kids {
    my $op = shift;
    my @rv;
    if (class($op) eq "LISTOP") { 
        $op = $op->first;
        push @rv, $op while $op->can("sibling") and $op = $op->sibling and $$op;
        return @rv;
    }
    push @rv, $op->first if $op->can("first") and $op->first and ${$op->first};
    push @rv, $op->last if $op->can("last") and $op->last and ${$op->last};
    push @rv, $op->other if $op->can("other") and $op->other and ${$op->other};
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
        if (!$target->seq);
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
        defined($x = $search->($_)) and return $x for $node->kids;

        # Not in this subtree.
        $deadend{$node}++;
        return undef;
   };
   my $result;
   my $start = $target;
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
   $result = $search->($start) and return $result
        while $start = $start->next;
}

=item walkoptree_simple($op, \&callback, [$data])

The C<B> module provides various functions to walk the op tree, but
they're all rather difficult to use, requiring you to inject methods
into the C<B::OP> class. This is a very simple op tree walker with
more expected semantics.

All the C<walk> functions set C<B::Utils::file> and C<B::Utils::line>
to the appropriate values of file and line number in the program
being examined.

=cut

our ($file, $line) = ("__none__",0);

sub walkoptree_simple {
    my ($op, $callback, $data) = @_;
    ($file, $line) = ($op->file, $op->line) if $op->isa("B::COP");
    $callback->($op,$data);
    if ($$op && ($op->flags & OPf_KIDS)) {
        my $kid;
        for ($kid = $op->first; $$kid; $kid = $kid->sibling) {
            walkoptree_simple($kid, $callback, $data);
        }
    }
}

=item walkoptree_filtered($op, \&filter, \&callback, [$data])

This is much the same as C<walkoptree_simple>, but will only call the
callback if the C<filter> returns true. The C<filter> is passed the 
op in question as a parameter; the C<opgrep> function is fantastic 
for building your own filters.

=cut

sub walkoptree_filtered {
    my ($op, $filter, $callback, $data) = @_;
    ($file, $line) = ($op->file, $op->line) if $op->isa("B::COP");
    $callback->($op,$data) if $filter->($op);
    if ($$op && ($op->flags & OPf_KIDS)) {
        my $kid;
        for ($kid = $op->first; $$kid; $kid = $kid->sibling) {
            walkoptree_filtered($kid, $filter, $callback, $data);
        }
    }
}

=item walkallops_simple(\&callback, [$data])

This combines C<walkoptree_simple> with C<all_roots> and C<anon_subs>
to examine every op in the program. C<$B::Utils::sub> is set to the
subroutine name if you're in a subroutine, C<__MAIN__> if you're in
the main program and C<__ANON__> if you're in an anonymous subroutine.

=cut

our $sub;

sub walkallops_simple {
    my ($callback, $data) = @_;
    _init();
    for $sub (keys %roots) {
        walkoptree_simple($roots{$sub}, $callback, $data);
    }
    $sub = "__ANON__";
    for (@anon_subs) {
        walkoptree_simple($_->{root}, $callback, $data);
    }
}

=item walkallops_filtered(\&filter, \&callback, [$data])

Same as above, but filtered.

=cut

sub walkallops_filtered {
    my ($filter, $callback, $data) = @_;
    _init();
    for $sub (keys %roots) {
        walkoptree_filtered($roots{$sub}, $filter, $callback, $data);
    }
    $sub = "__ANON__";
    for (@anon_subs) {
        walkoptree_filtered($_->{root}, $filter, $callback, $data);
    }
}

=item carp(@args) 

=item croak(@args) 

Warn and die, respectively, from the perspective of the position of the op in
the program. Sounds complicated, but it's exactly the kind of error reporting
you expect when you're grovelling through an op tree.

=cut

sub _preparewarn {
    my $args = join '', @_;
    $args = "Something's wrong " unless $args;
    $args .= " at $file line $line.\n" unless substr($args, length($args) -1) eq "\n";
}

sub carp  (@) { CORE::die(preparewarn(@_)) }
sub croak (@) { CORE::warn(preparewarn(@_)) }

=item opgrep(\%conditions, @ops)

Returns the ops which meet the given conditions. The conditions should be
specified like this:

    @barewords = opgrep(
                        { name => "const", private => OPpCONST_BARE },
                        @ops
                       );

You can specify alternation by giving an arrayref of values:

    @svs = opgrep ( { name => ["padsv", "gvsv"] }, @ops)

And you can specify inversion by making the first element of the arrayref
a "!". (Hint: if you want to say "anything", say "not nothing": C<["!"]>)

You may also specify the conditions to be matched in nearby ops.

    walkallops_filtered(
        sub { opgrep( {name => "exec", 
                       next => {
                                 name    => "nextstate",
                                 sibling => { name => [qw(! exit warn die)] }
                               }
                      }, @_)},
        sub { 
              carp("Statement unlikely to be reached"); 
              carp("\t(Maybe you meant system() when you said exec()?)\n");
        }
    )

Get that?

Here are the things that can be tested:

        name targ type seq flags private pmflags pmpermflags
        first other last sibling next pmreplroot pmreplstart pmnext

=cut

sub opgrep {
    my ($cref, @ops) = @_;
    my %conds = %$cref;
    my @rv = ();
    my $o;
    OPLOOP: for $o (@ops) {
        # First, let's skim off ops of the wrong type.
        for (qw(first other last pmreplroot pmreplstart pmnext pmflags pmpermflags)) {
            next OPLOOP if exists $conds{$_} and !$o->can($_);
        }

        for my $test (qw(name targ type seq flags private pmflags pmpermflags)) {
            next unless exists $conds{$test};
            next OPLOOP unless ref $o and $o->can($test);
	    if (!ref $conds{$test}) {
	       next OPLOOP if $o->$test ne $conds{$test};
	    } else {
		    if ($conds{$test}[0] eq "!") {
			my @conds = @{$conds{$test}}; shift @conds;
			next OPLOOP if grep {$o->$test eq $_} @conds;
		    } else {
			next OPLOOP unless grep {$o->$test eq $_} @{$conds{$test}};
		    }
	    }
        }

        for my $neighbour (qw(first other last sibling next pmreplroot pmreplstart pmnext)) {
            next unless exists $conds{$neighbour};
            # We know it can, because we tested that above
            # Recurse, recurse!
            next OPLOOP unless opgrep($conds{$neighbour}, $o->$neighbour);
        }

        push @rv, $_;
    }
    return @rv;
}

1;

=back

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
