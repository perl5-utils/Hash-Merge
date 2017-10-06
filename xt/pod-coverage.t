#! perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    $] >= 5.008 or plan skip_all => "Test::Pod::Coverage requires perl 5.8";
}
use Test::Pod::Coverage;
use Pod::Coverage;

all_pod_coverage_ok({trustme => [qr/^new$/]});

done_testing();
