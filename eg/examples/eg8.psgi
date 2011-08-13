use strict;
use warnings;

use Hopen;
use Plack::Builder;
use Cache::FileCache;
use File::Temp qw/tempdir/;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), qw/lib/);

my $cache_info = {
    'cache_root'         => tempdir,
    'namespace'          => 'hoge',
    'default_expires_in' => '1h',
};

{ # fixture
    my $cache = Cache::FileCache->new( $cache_info );
    map { $cache->set($_, uc($_ x 3)) } qw/hoge fuga piyo/;
}

load_plugins('eg::Plugin::FileCache');

get '/' => sub {
     my $c = shift;
     $c->render('index', { keys => [ $c->cache->get_keys ] });
};

get '/:key' => sub {
    my ($c, $params) = @_;
    if(my $value = $c->cache->get($params->{key})) {
        return "<h1>$value</h1>";
    }
    $c->res_404;
};

hopen( 'Cache::FileCache' => $cache_info );

__DATA__

@@ index
<ul>
[%- WHILE (key = keys.shift()) -%]
  <li><a href="/[% key %]">[% key %]</a></li>
[%- END -%]
</ul>
