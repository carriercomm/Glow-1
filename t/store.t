use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use t::TestGit;
our (%objects);

# a loose backend to read from
my $loose_r = Glow::Repository::Git::Storage::Loose->new(
    directory => 't/git/objects',
    readonly  => 1
);

# a loose backend to write to
my $loose_w = Glow::Repository::Git::Storage::Loose->new(
    directory => tempdir( CLEANUP => 1 ) );

# a store pointing to both
my $store = Glow::Store->new( stores => [ $loose_r, $loose_w ] );

# create a random object, not in any storage
my $blob = Glow::Repository::Git::Object::Blob->new(
    content => 'some random string' );
ok( !$loose_r->has_object( $blob->digest ), 'blob not in readonly storage' );
ok( !$loose_w->has_object( $blob->digest ), 'blob not in writable storage' );

# save it to the store
ok( $store->put_object($blob), 'blob saved in the store' );

# check it ended in the writable storage
ok( !$loose_r->has_object( $blob->digest ), 'blob not in the readonly store' );
ok( $loose_w->has_object( $blob->digest ), 'blob now in the writable store' );

# remove it
ok( $store->delete_object( $blob->digest ), 'blob deleted from the store' );

# check it's gone
ok( !$loose_r->has_object( $blob->digest ), 'blob not in readonly storage' );
ok( !$loose_w->has_object( $blob->digest ), 'blob not in writable storage' );

# remove it again
ok( !$store->delete_object( $blob->digest ),
    'absent blob not deleted from the store'
);

done_testing;

