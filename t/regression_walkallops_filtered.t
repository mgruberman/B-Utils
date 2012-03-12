use strict;
use warnings;

use Test::Exception tests => 1;

use B::Utils qw( walkallops_filtered opgrep );

lives_ok {
    walkallops_filtered(
        sub { opgrep( {name => "exec",
                    next => {
                                name    => "nextstate",
                                sibling => { name => [qw(! exit warn die)] }
                            }
                    }, @_)},
        sub {
            warn("Statement unlikely to be reached");
            warn("\t(Maybe you meant system() when you said exec()?)\n");
        }
    )
} 'walkallops_filtered should not die when called as documented';

