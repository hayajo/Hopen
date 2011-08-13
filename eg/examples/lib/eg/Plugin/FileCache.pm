package eg::Plugin::FileCache;

use strict;
use warnings;

use Cache::FileCache;

sub init {
    my ($class, $c, $params) = @_;
    no strict 'refs';
    *{ "$c\::cache" } = \&_cache;
}

sub _cache {
    my $self = shift;
    if (! $self->{cache}) {
        my $conf = $self->config->{'Cache::FileCache'}
            or Carp::croak "no configureation 'Cache::FileCache'";
        $self->{cache} = Cache::FileCache->new($conf);
    }
    $self->{cache};
}

1;
