#!perl

use strict;
use warnings;

use Test::More;
use Test::PerlTidy;

run_tests(
    perltidyrc => '.perltidyrc',
    exclude    => ['t/Auto/', 't/Clone/', 't/Storable/', 't/ClonePP/', 't/inline/']
);
