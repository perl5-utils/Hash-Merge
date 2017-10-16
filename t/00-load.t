#!perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    use_ok('Hash::Merge') || BAIL_OUT("Couldn't load Hash::Merge");
}

diag("Testing Hash::Merge version $Hash::Merge::VERSION, Perl $], $^X");
diag("Using Clone::Choose version $Clone::Choose::VERSION");
my $backend = Clone::Choose->backend;

diag("Using backend $backend version " . $backend->VERSION);

done_testing;
