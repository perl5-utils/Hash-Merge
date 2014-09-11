#!/usr/bin/perl -w

use strict;
use Test::More tests=>27;
use Hash::Merge;

my %left = ( ss => 'left',
             sa => 'left',
	     sh => 'left',
	     as => [ 'l1', 'l2' ],
	     aa => [ 'l1', 'l2' ],
	     ah => [ 'l1', 'l2' ],
	     hs => { left=>1 },
	     ha => { left=>1 },
	     hh => { left=>1 } );

my %right = ( ss => 'right',
	      as => 'right',
	      hs => 'right',
	      sa => [ 'r1', 'r2' ],
	      aa => [ 'r1', 'r2' ],
	      ha => [ 'r1', 'r2' ],
	      sh => { right=>1 },
	      ah => { right=>1 },
	      hh => { right=>1 } );

# Test left precedence
my $merge = Hash::Merge->new();
ok($merge->get_behavior() eq 'LEFT_PRECEDENT', 'no arg default is LEFT_PRECEDENT');


my %lp = %{$merge->merge( \%left, \%right )};

is_deeply( $lp{ss},	'left',						'Left Precedent - Scalar on Scalar' );
is_deeply( $lp{sa},	'left',						'Left Precedent - Scalar on Array' );
is_deeply( $lp{sh},	'left',						'Left Precedent - Scalar on Hash' );
is_deeply( $lp{as},	[ 'l1', 'l2', 'right'],		'Left Precedent - Array on Scalar' );
is_deeply( $lp{aa},	[ 'l1', 'l2', 'r1', 'r2' ],	'Left Precedent - Array on Array' );
is_deeply( $lp{ah},	[ 'l1', 'l2', 1 ],			'Left Precedent - Array on Hash' );
is_deeply( $lp{hs},	{ left=>1 },				'Left Precedent - Hash on Scalar' );
is_deeply( $lp{ha},	{ left=>1 },				'Left Precedent - Hash on Array' );
is_deeply( $lp{hh},	{ left=>1, right=>1 },		'Left Precedent - Hash on Hash' );

ok($merge->set_behavior('RIGHT_PRECEDENT') eq 'LEFT_PRECEDENT', 'set_behavior() returns previous behavior');
ok($merge->get_behavior() eq 'RIGHT_PRECEDENT', 'set_behavior() actually sets the behavior)');

is $merge->get_path_behavior, undef;
is( $merge->set_path_behavior(1), undef );
is $merge->get_path_behavior, 1;

$left{oss}  = 'left';
$right{oss} = 'right';

$left{ohh}  = { left => 1 };
$right{ohh} = { right => 1 };

$left{mlhh}  = { key => { left => 1 }, test => 1 };
$right{mlhh} = { key => { right =>1 }, another_key => 1 };

$merge->specify_behavior({
        'SCALAR' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ $_[0], @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'ARRAY' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ @{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'HASH' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ values %{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1], $_[2] ) },
        },
        paths => {
            '/ss'       => sub { $_[0] },
            '/hh'       => sub { my %hash = ( %{$_[0]}, %{$_[1]} ); $hash{$_} *= 2  for keys %hash; \%hash },
            '/mlhh/key' => sub { $_[1] },
        },
    }, 'RIGHT_PRECEDENT');

my %rp = %{$merge->merge( \%left, \%right )};

is_deeply( $rp{ss},	'left',							'Right Precedent - Scalar on Scalar - path' );
is_deeply( $rp{oss},	'right',						'Right Precedent - Scalar on Scalar' );
is_deeply( $rp{sa},	[ 'left', 'r1', 'r2' ],					'Right Precedent - Scalar on Array' );
is_deeply( $rp{sh},	{ right=>1 },						'Right Precedent - Scalar on Hash' );
is_deeply( $rp{as},	'right',						'Right Precedent - Array on Scalar' );
is_deeply( $rp{aa},	[ 'l1', 'l2', 'r1', 'r2' ],				'Right Precedent - Array on Array' );
is_deeply( $rp{ah},	{ right=>1 },						'Right Precedent - Array on Hash' );
is_deeply( $rp{hs},	'right',						'Right Precedent - Hash on Scalar' );
is_deeply( $rp{ha},	[ 1, 'r1', 'r2' ], 					'Right Precedent - Hash on Array' );
is_deeply( $rp{hh},	{ left=>2, right=>2 },					'Right Precedent - Hash on Hash - path' );
is_deeply( $rp{ohh},	{ left=>1, right=>1 },					'Right Precedent - Hash on Hash' );
is_deeply( $rp{mlhh},	{ test=>1, another_key=>1, key => {right => 1} },	'Right Precedent - Hash on Hash - multilevel path' );
