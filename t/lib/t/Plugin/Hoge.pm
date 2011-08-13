package t::Plugin::Hoge;

use strict;
use warnings;

sub init {
    my ($class, $c, $params) = @_;
    no strict 'refs';
    *{ "$c\::hoge" } = sub { $c->config->{'t::Plugin::Hoge'} || 'hoge' };
}

1;
