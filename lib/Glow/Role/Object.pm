package Glow::Role::Object;
use Moose::Role;

use Carp;
use FileHandle;
use IO::String;
use Fcntl qw( SEEK_END );
use Digest::SHA;

# all attributes are read-only

requires 'kind';

# these attributes can be generated, and need not to be set in the constructor
has size => (
    is       => 'ro',
    isa      => 'Int',
    lazy     => 1,
    required => 0,
    builder  => '_build_size',
);

has sha1 => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    required => 0,
    builder  => '_build_sha1',
);

# these attributes define the content, from which almost everything derives:
# - raw content, as a string
has content => (
    is        => 'ro',
    isa       => 'Str',
    lazy      => 1,
    required  => 0,
    builder   => '_build_content',
    predicate => 'has_content',
);

# - a coderef that returns a filehandle pointing at the content beginning
#   (BUILDARGS supports a 'source' parameter to pass in a filename instead)
has content_source => (
    is        => 'ro',
    isa       => 'CodeRef',
    required  => 0,
    predicate => 'has_content_source'
);

# turn the 'source' parameter into a 'content_source' parameter
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig(@_);
    if( exists $args->{source} ) {
        croak "Only one of argument source or content_source is allowed"
            if exists $args->{content_source};
        my $source = delete $args->{source};
        die "$source does not exist" if !-e $source;
        die "$source is unreadable"  if !-r $source;
        $args->{content_source} = sub {
            open my $fh, '<', $source or die "Can't open $source: $!";
            return $fh;
        };
    }
    return $args;
};

# we can only pass one of 'content' or 'content_source'
sub BUILD {
    my ($self) = @_;
    croak "At least one but only one of attributes content or content_source is required"
      if $self->has_content + $self->has_content_source != 1;
}

# builders
sub _build_size {
    my ($self) = @_;

    return length $self->content if $self->has_content;

    my $fh = $self->content_fh;
    $fh->seek( 0, SEEK_END );
    return $fh->tell;
}

sub _build_sha1 {
    my ($self) = @_;
    my $sha1 = Digest::SHA->new(1);
    $sha1->add( $self->kind . ' ' . $self->size . "\0" );
    if ( $self->has_content ) {
        $sha1->add( $self->content );
    }
    else {
        $sha1->addfile( $self->content_fh );
    }
    return $sha1->hexdigest;
}

sub _build_content {
    my ($self) = @_;
    my $fh = $self->content_fh;
    local $/;
    return <$fh> // '';
}

# methods
sub content_fh {
    my ($self) = @_;
    return $self->has_content_source
        ? $self->content_source->()
        : IO::String->new( $self->content );
}

1;