package Hash::Merge;

use strict;
use warnings;
use Carp;

use base 'Exporter';
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);

$VERSION     = sprintf( '%d.%02d', q($Revision: 0.11 $) =~ /\s(\d+)\.(\d+)/ );
@EXPORT_OK   = qw( merge _hashify _merge_hashes );
%EXPORT_TAGS = ( 'custom' => [ qw( _hashify _merge_hashes )] );


my $behaviors = {
    'LEFT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { $_[0] }, 
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{$_[0]}, $_[1] ] },
            'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
            'HASH'   => sub { [ @{$_[0]}, values %{$_[1]} ] }, 
        },
        'HASH' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) }, 
        },
    },
    
    'RIGHT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ $_[0], @{$_[1]} ] },
            'HASH'   => sub { $_[1] }, 
        },
        'ARRAY' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
            'HASH'   => sub { $_[1] }, 
        },
        'HASH' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ values %{$_[0]}, @{$_[1]} ] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) }, 
        },
    },
    
    'STORAGE_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { [ $_[0], @{$_[1]} ] },
            'HASH'   => sub { $_[1] }, 
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{$_[0]}, $_[1] ] },
            'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
            'HASH'   => sub { $_[1] }, 
        },
        'HASH' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) }, 
        },
    },
    
    'RETAINMENT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { [ $_[0], $_[1] ] },
            'ARRAY'  => sub { [ $_[0], @{$_[1]} ] },
            'HASH'   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) },
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{$_[0]}, $_[1] ] },
            'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
            'HASH'   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) }, 
        },
        'HASH' => {
            'SCALAR' => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
            'ARRAY'  => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) }, 
        },
    },
};

my $merge_behavior = 'LEFT_PRECEDENT';
my $merge_matrix   = $behaviors->{ $merge_behavior };
my $clone_behavior = 1;

sub set_behavior {
    my $value = uc(shift);
    if( !exists $behaviors->{ $value } ) {
        carp 'Behavior must be one of : ' . join( ', ', keys %{ $behaviors } );
        return;
    }
    
    $merge_behavior = $value;
    $merge_matrix   = $behaviors->{ $merge_behavior };
}

sub get_behavior {
    return $merge_behavior;
}

sub specify_behavior {
    my ( $matrix, $name ) = @_;
    $name ||= 'user defined';
    
    my @required = qw( SCALAR ARRAY HASH );
  
    foreach my $left ( @required ) {
        foreach my $right ( @required ) {
            if( !exists $matrix->{ $left }->{ $right } ) {
                carp "Behavior does not specify action for '$left' merging with '$right'";
                return;
            }
        }
    }
  
    $merge_behavior = $name;
    $merge_matrix   = $matrix;
}

sub set_clone_behavior {
    $clone_behavior = shift() ? 1 : 0;
}

sub get_clone_behavior {
    return $clone_behavior;
}

sub merge {
    my ( $left, $right ) = @_;

    # For the general use of this module, we want to create duplicates
    # of all data that is merged.  This behavior can be shut off, but 
    # can mess havoc if references are used heavily.

    my $lefttype = ref $left eq 'HASH'  ? 'HASH'
                 : ref $left eq 'ARRAY' ? 'ARRAY'
                 :                        'SCALAR'
                 ;

    my $righttype = ref $right eq 'HASH'  ? 'HASH'
                  : ref $right eq 'ARRAY' ? 'ARRAY'
                  :                         'SCALAR'
                  ;

    if ( $clone_behavior ) {
        $left  = _my_clone( $left,  1 ); 
        $right = _my_clone( $right, 1 );
    }

    return $merge_matrix->{ $lefttype }{ $righttype }->( $left, $right );
}	

# This does a straight merge of hashes, delegating the merge-specific 
# work to 'merge'

sub _merge_hashes {
    my ( $left, $right ) = ( shift, shift );
    if( ref $left ne 'HASH' || ref $right ne 'HASH' ) {
        carp 'Arguments for _merge_hashes must be hash references';
        return;
    }

    my %newhash;
    foreach my $leftkey ( keys %$left ) {
        if ( exists $right->{ $leftkey } ) {
            $newhash{ $leftkey } 
                = merge ( $left->{ $leftkey }, $right->{ $leftkey } );
        } 
        else {
            $newhash{ $leftkey } = $clone_behavior 
                ? _my_clone( $left->{ $leftkey } ) : $left->{ $leftkey };
        }
    }
    
    foreach my $rightkey ( keys %$right ) { 
        if ( !exists $left->{ $rightkey } ) {
            $newhash{ $rightkey } = $clone_behavior 
                ? _my_clone( $right->{ $rightkey } ) : $right->{ $rightkey };
        }
    }
    
    return \%newhash;
}

# Given a scalar or an array, creates a new hash where for each item in
# the passed scalar or array, the key is equal to the value.  Returns
# this new hash

sub _hashify {
    my $arg = shift;
    if( ref $arg eq 'HASH' ) {
        carp 'Arguement for _hashify must not be a HASH ref';
        return;
    }
   
    my %newhash;
    if ( ref $arg eq 'ARRAY' ) {
        foreach my $item ( @$arg ) {
            my $suffix = 2;
            my $name = $item;
            while ( exists $newhash{ $name } ) {
	            $name = $item . $suffix++;
            }
            $newhash{ $name } = $item;
        }
    } 
    else {
        $newhash{ $arg } = $arg;
    }
    return \%newhash;
}

# This adds some checks to the clone process, to deal with problems that 
# the current distro of ActiveState perl has (specifically, it uses 0.09
# of Clone, which does not support the cloning of scalars).  This simply
# wraps around clone as to prevent a scalar from being cloned via a 
# Clone 0.09 process.  This might mean that CODEREFs and anything else
# not a HASH or ARRAY won't be cloned.

sub _my_clone {
    my ( $arg, $depth ) = @_;

    if( $clone_behavior ) {
        require Clone;
    }

    if ( !($Clone::VERSION || 0) > 0.09 
         && ref $arg ne 'HASH' 
         && ref $arg ne 'ARRAY'
    ) { 
        my $var = $arg; # Forced clone
        return $var;
    } 
    else {
        if ($depth ) {
            return Clone::clone( $arg, $depth );
        } 
        else {
            return Clone::clone( $arg );
        }
    }
}

1;

__END__

=head1 NAME

Hash::Merge - Merges arbitrarily deep hashes into a single hash

=head1 SYNOPSIS

    use Hash::Merge qw( merge );
    my %a = ( 
		'foo'    => 1,
	    'bar'    => [ qw( a b e ) ],
	    'querty' => { 'bob' => 'alice' },
	);
    my %b = ( 
		'foo'     => 2, 
		'bar'    => [ qw(c d) ],
		'querty' => { 'ted' => 'margeret' }, 
	);

    my %c = %{ merge( \%a, \%b ) };

    Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );

    # This is the same as above

	Hash::Merge::specify_behavior(
	    {
			'SCALAR' => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ $_[0], @{$_[1]} ] },
				'HASH'   => sub { $_[1] },
			},
			'ARRAY => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
				'HASH'   => sub { $_[1] }, 
			},
			'HASH' => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ values %{$_[0]}, @{$_[1]} ] },
				'HASH'   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) }, 
			},
		}, 
		'My Behavior', 
	);

=head1 DESCRIPTION

Hash::Merge merges two arbitrarily deep hashes into a single hash.  That
is, at any level, it will add non-conflicting key-value pairs from one
hash to the other, and follows a set of specific rules when there are key
value conflicts (as outlined below).  The hash is followed recursively,
so that deeply nested hashes that are at the same level will be merged 
when the parent hashes are merged.  B<Please note that self-referencing
hashes, or recursive references, are not handled well by this method.>

Values in hashes are considered to be either ARRAY references, 
HASH references, or otherwise are treated as SCALARs.  By default, the 
data passed to the merge function will be cloned using the Clone module; 
however, if necessary, this behavior can be changed to use as many of 
the original values as possible.  (See C<set_clone_behavior>). 

Because there are a number of possible ways that one may want to merge
values when keys are conflicting, Hash::Merge provides several preset
methods for your convenience, as well as a way to define you own.  
These are (currently):

=over

=item Left Precedence

The values buried in the left hash will never
be lost; any values that can be added from the right hash will be
attempted.

=item Right Precedence

Same as Left Precedence, but with the right
hash values never being lost

=item Storage Precedence

If conflicting keys have two different
storage mediums, the 'bigger' medium will win; arrays are preferred over
scalars, hashes over either.  The other medium will try to be fitted in
the other, but if this isn't possible, the data is dropped.

=item Retainment Precedence

No data will be lost; scalars will be joined
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

=item set_clone_behavior( <scalar> ) 

Sets how the data cloning is handled by Hash::Merge.  If this is true,
then data will be cloned; if false, then original data will be used
whenever possible.  By default, cloning is on (set to true).

=item get_clone_behavior( )

Returns the current behavior for data cloning.

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

Note that you can import _hashify and _merge_hashes into your program's
namespace with the 'custom' tag.

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

As of Feb 16, 2002, ActiveState Perl's PPM of Clone.pm is only at
0.09.  This version does not support the cloning of scalars if passed
to the function.  This is fixed by 0.10 (and currently, Clone.pm is at
0.13).  So while most other users can upgrade their Clone.pm
appropriately (and I could put this as a requirement into the
Makefile.PL), those using ActiveState would lose out on the ability to
use this module.  (Clone.pm is not pure perl, so it's not simply a
matter of moving the newer file into place).  Thus, for the time
being, a check is done at the start of loading of this module to see
if a newer version of clone is around.  Then, all cloning calls have
been wrapped in the internal _my_clone function to block any scalar
clones if Clone.pm is too old.  However, this also prevents the
cloning of anything that isn't a hash or array under the same
conditions.  Once ActiveState updates their Clone, I'll remove this 
wrapper.

=head1 AUTHOR

Michael K. Neylon E<lt>mneylon-pm@masemware.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2001,2002 Michael K. Neylon. All rights reserved.

This library is free software.  You can redistribute it and/or modify it 
under the same terms as Perl itself.

=cut