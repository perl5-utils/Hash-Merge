#!/usr/bin/perl -w

package Hash::Merge;

#=============================================================================
#
# $Id: Merge.pm,v 0.05 2001/11/02 02:15:54 mneylon Exp $
# $Revision: 0.05 $
# $Author: mneylon $
# $Date: 2001/11/02 02:15:54 $
# $Log: Merge.pm,v $
# Revision 0.05  2001/11/02 02:15:54  mneylon
# Yet another fix to Test::More requirement (=> 0.33)
#
# Revision 0.04  2001/10/31 03:59:03  mneylon
# Forced Test::More requirement in makefile
# Fixed problems with pod documentation
#
# Revision 0.03  2001/10/28 23:36:12  mneylon
# CPAN Release with CVS fixes
#
# Revision 0.02  2001/10/28 23:05:03  mneylon
# CPAN release
#
# Revision 0.01.1.1  2001/10/23 03:01:34  mneylon
# Slight fixes
#
# Revision 0.01  2001/10/23 03:00:21  mneylon
# Initial Release to PerlMonks
#
#
#=============================================================================

use strict;

BEGIN {
    use Exporter   ();
    use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = sprintf( "%d.%02d", q($Revision: 0.05 $) =~ /\s(\d+)\.(\d+)/ );
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
	@EXPORT_OK   = qw( merge );
    %EXPORT_TAGS = ( );
}

my %left_precedent = (
	SCALAR => {
		SCALAR => sub { $_[0] },
		ARRAY  => sub { $_[0] },
		HASH   => sub { $_[0] } },
	ARRAY => {
		SCALAR => sub { [ @{$_[0]}, $_[1] ] },
		ARRAY  => sub { [ @{$_[0]}, @{$_[1]} ] },
		HASH   => sub { [ @{$_[0]}, values %{$_[1]} ] } },
	HASH => {
		SCALAR => sub { $_[0] },
		ARRAY  => sub { $_[0] },
		HASH   => sub { _merge_hashes( $_[0], $_[1] ) } }
);

my %right_precedent = (
	SCALAR => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ $_[0], @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	ARRAY => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ @{$_[0]}, @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	HASH => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ values %{$_[0]}, @{$_[1]} ] },
		HASH   => sub { _merge_hashes( $_[0], $_[1] ) } }
);

my %storage_precedent = (
	SCALAR => {
		SCALAR => sub { $_[0] },
		ARRAY  => sub { [ $_[0], @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	ARRAY => {
		SCALAR => sub { [ @{$_[0]}, $_[1] ] },
		ARRAY  => sub { [ @{$_[0]}, @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	HASH => {
		SCALAR => sub { $_[0] },
		ARRAY  => sub { $_[0] },
		HASH   => sub { _merge_hashes( $_[0], $_[1] ) } }
);

my %retainment_precedent = (
	SCALAR => {
		SCALAR => sub { [ $_[0], $_[1] ] },
		ARRAY  => sub { [ $_[0], @{$_[1]} ] },
		HASH   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) } },
	ARRAY => {
		SCALAR => sub { [ @{$_[0]}, $_[1] ] },
		ARRAY  => sub { [ @{$_[0]}, @{$_[1]} ] },
		HASH   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) } },
	HASH => {
		SCALAR => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
		ARRAY  => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
		HASH   => sub { _merge_hashes( $_[0], $_[1] ) } }
);

my %behaviors = (
	LEFT_PRECEDENT => \%left_precedent,
	RIGHT_PRECEDENT => \%right_precedent,
	STORAGE_PRECEDENT => \%storage_precedent,
	RETAINMENT_PRECEDENT => \%retainment_precedent 
);

my $merge_behavior = 'LEFT_PRECEDENT';
my $merge_matrix = \%{ $behaviors{ $merge_behavior } };

sub set_behavior {
	my $value = uc(shift);
	die "Behavior must be one of : " , join ' ', keys %behaviors 
		unless exists $behaviors{ $value };
	$merge_behavior = $value;
	$merge_matrix = \%{ $behaviors{ $merge_behavior } };
}

sub get_behavior {
	return $merge_behavior;
}

sub specify_behavior {
	my $matrix = shift;
	my $name = shift || "user defined";
	my @required = qw ( SCALAR ARRAY HASH );

	foreach my $left ( @required ) {
		foreach my $right ( @required ) {
			die "Behavior does not specify action for $left merging with $right"
				unless exists $matrix->{ $left }->{ $right };
		}
	}

	$merge_behavior = $name;
	$merge_matrix = $matrix;
}

sub merge {
	my ( $left, $right ) = ( shift, shift );

	my ( $lefttype, $righttype );
	if ( UNIVERSAL::isa( $left, 'HASH' ) ) { 
		$lefttype = 'HASH';
	} elsif ( UNIVERSAL::isa( $left, 'ARRAY' ) ) {
		$lefttype = 'ARRAY';
	} else {
		$lefttype = 'SCALAR';
	}

	if ( UNIVERSAL::isa( $right, 'HASH' ) ) { 
		$righttype = 'HASH';
	} elsif ( UNIVERSAL::isa( $right, 'ARRAY' ) ) {
		$righttype = 'ARRAY';
	} else {
		$righttype = 'SCALAR';
	}
	
	return &{ $merge_matrix->{ $lefttype }->{ $righttype }}
		( $left, $right );
}	

# This does a straight merge of hashes, delegating the merge-specific 
# work to 'merge'

sub _merge_hashes {
	my ( $left, $right ) = ( shift, shift );
	die "Arguments for _merge_hashes must be hash references" unless 
		UNIVERSAL::isa( $left, 'HASH' ) && UNIVERSAL::isa( $right, 'HASH' );
	
	my %newhash;
	foreach my $leftkey ( keys %$left ) {
		if ( exists $right->{ $leftkey } ) {
			$newhash{ $leftkey } = 
				merge ( $left->{ $leftkey }, $right->{ $leftkey } )
		} else {
			$newhash{ $leftkey } = $left->{ $leftkey };
		}
	}
	foreach my $rightkey ( keys %$right ) { 
		if ( !exists $left->{ $rightkey } ) {
			$newhash{ $rightkey } = $right->{ $rightkey }
		}
	}
	return \%newhash;
}

# Given a scalar or an array, creates a new hash where for each item in
# the passed scalar or array, the key is equal to the value.  Returns
# this new hash
 
sub _hashify {
	my $arg = shift;
	die "Arguement for _hashify must not be a HASH ref" if
		UNIVERSAL::isa( $arg, 'HASH' );
	
	my %newhash;
	if ( UNIVERSAL::isa( $arg, 'ARRAY' ) ) {
		foreach my $item ( @$arg ) {
		    my $suffix = 2;
			my $name = $item;
			while ( exists $newhash{ $name } ) {
				$name = $item . $suffix++;
			}
			$newhash{ $name } = $item;
		}
	} else {
		$newhash{ $arg } = $arg;
	}
	return \%newhash;
}

1;
__END__

=head1 NAME

Hash::Merge - Merges arbitrarily deep hashes into a single hash

=head1 SYNOPSIS

  use Hash::Merge qw( merge );
  my %a = ( foo => 1,
            bar => [ a, b, e ],
		    querty => { bob => alice } );
  my %b = ( foo => 2, 
            bar => [ c, d ],
			querty => { ted => margeret } );

  my %c = merge( \%a, \%b );

  Hash::Merge::set_behavior( RIGHT_PRECEDENCE );

  # This is the same as above

  Hash::Merge::specify_behavior( {
  	SCALAR => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ $_[0], @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	ARRAY => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ @{$_[0]}, @{$_[1]} ] },
		HASH   => sub { $_[1] } },
	HASH => {
		SCALAR => sub { $_[1] },
		ARRAY  => sub { [ values %{$_[0]}, @{$_[1]} ] },
		HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) } }
  }, "My Behavior" );

=head1 DESCRIPTION

Hash::Merge merges two arbitrarily deep hashes into a single hash.  That
is, at any level, it will add non-conflicting key-value pairs from one
hash to the other, and follows a set of specific rules when there are key
value conflicts (as outlined below).  The hash is followed recursively,
so that deeply nested hashes that are at the same level will be merged 
when the parent hashes are merged.  B<Please note that self-referencing
hashes, or recursive references, are not handled well by this method.>

Values in hashes are considered to be either ARRAY references, 
HASH references, or otherwise are treated as SCALARs.

Because there are a number of possible ways that one may want to merge
values when keys are conflicting, Hash::Merge provides several preset
methods for your convenience, as well as a way to define you own.  
These are (currently):

=over

=item *
Left Precedence - The values buried in the left hash will never
be lost; any values that can be added from the right hash will be
attempted.

=item *
Right Precedence - Same as Left Precedence, but with the right
hash values never being lost

=item *
Storage Precedence - If conflicting keys have two different
storage mediums, the 'bigger' medium will win; arrays are preferred over
scalars, hashes over either.  The other medium will try to be fitted in
the other, but if this isn't possible, the data is dropped.

=item *
Retainment Precedence - No data will be lost; scalars will be joined
with arrays, and scalars and arrays will be 'hashified' to fit them into
a hash.

=back

Specific descriptions of how these work are detailed below.

=over 

=item merge ( <hashref>, <hashref> )

Merges two hashes given the rules specified.  Returns a reference to 
the new hash.

=item _hashify( <scalar>|<arrayref> ) -- INTERNAL FUNCTION

Returns a reference to a hash created from the scalar or array reference, 
where, for the scalar value, or each item in the array, there is a key
and it's value equal to that specific value.  Example, if you pass scalar
'3', the hash will be { 3 => 3 }.

=item _merge_hashes( <hashref>, <hashref> ) -- INTERNAL FUNCTION

Actually does the key-by-key evaluation of two hashes and returns 
the new merged hash.  Note that this recursively calls C<merge>.

=item set_behavior( <scalar> )

Specify which built-in behavior for merging that is desired.  The scalar
must be one of those given below.

=item get_behavior( )

Returns the behavior that is currently in use by Hash::Merge.

=item specify_behavior( <hashref>, [<name>] )

Specify a custom merge behavior for Hash::Merge.  This must be a hashref
defined with (at least) 3 keys, SCALAR, ARRAY, and HASH; each of those
keys must have another hashref with (at least) the same 3 keys defined.
Furthermore, the values in those hashes must be coderefs.  These will be
called with two arguments, the left and right values for the merge.  
Your coderef should return either a scalar or an array or hash reference
as per your planned behavior.  If necessary, use the functions
_hashify and _merge_hashes as helper functions for these.  For example,
if you want to add the left SCALAR to the right ARRAY, you can have your
behavior specification include:

   %spec = ( ...SCALAR => { ARRAY => sub { [ $_[0], @$_[1] ] }, ... } } );

=back

=head1 BUILT-IN BEHAVIORS

Here is the specifics on how the current internal behaviors are called, 
and what each does.  Assume that the left value is given as $a, and
the right as $b (these are either scalars or appropriate references)

LEFT TYPE   RIGHT TYPE      LEFT_PRECEDENT       RIGHT_PRECEDENT
 SCALAR      SCALAR            $a                   $b
 SCALAR      ARRAY             $a                   ( $a, @$b )
 SCALAR      HASH              $a                   %$b
 ARRAY       SCALAR            ( @$a, $b )          $b
 ARRAY       ARRAY             ( @$a, @$b )         ( @$a, @$b )
 ARRAY       HASH              ( @$a, values %$b )  %$b 
 HASH        SCALAR            %$a                  $b
 HASH        ARRAY             %$a                  ( values %$a, @$b )
 HASH        HASH              merge( %$a, %$b )    merge( %$a, %$b )

LEFT TYPE   RIGHT TYPE  STORAGE_PRECEDENT   RETAINMENT_PRECEDENT
 SCALAR      SCALAR     $a                  ( $a ,$b )
 SCALAR      ARRAY      ( $a, @$b )         ( $a, @$b )
 SCALAR      HASH       %$b                 merge( hashify( $a ), %$b )
 ARRAY       SCALAR     ( @$a, $b )         ( @$a, $b )
 ARRAY       ARRAY      ( @$a, @$b )        ( @$a, @$b )
 ARRAY       HASH       %$b                 merge( hashify( @$a ), %$b )
 HASH        SCALAR     %$a                 merge( %$a, hashify( $b ) )
 HASH        ARRAY      %$a                 merge( %$a, hashify( @$b ) )
 HASH        HASH       merge( %$a, %$b )   merge( %$a, %$b )

(*) note that merge calls _merge_hashes, hashify calls _hashify.

=head1 CAVEATS

This will not handle self-referencing/recursion within hashes well.  
Plans for a future version include incorporate deep recursion protection.

=head1 AUTHOR

Michael K. Neylon E<lt>mneylon-pm@masemware.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2001 Michael K. Neylon. All rights reserved.

This library is free software.  You can redistribute it and/or modify it 
under the same terms as Perl itself.

=head1 HISTORY

$Log: Merge.pm,v $
Revision 0.05  2001/11/02 02:15:54  mneylon
Yet another fix to Test::More requirement (=> 0.33)

Revision 0.04  2001/10/31 03:59:03  mneylon
Forced Test::More requirement in makefile
Fixed problems with pod documentation

Revision 0.03  2001/10/28 23:36:12  mneylon
CPAN Release with CVS fixes

Revision 0.02  2001/10/28 23:05:03  mneylon
CPAN release


=cut
