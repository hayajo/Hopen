use strict;
use warnings;

use Test::More;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), qw/lib/);

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/' => sub {
        $_[0]->hoge;
    };
    load_plugins('t::Plugin::Hoge');
    hopen( 't::Plugin::Hoge' => "HOGE" );
};

{
    my $get = sub {
        $app->({
            REQUEST_METHOD => 'GET',
            PATH_INFO      => shift || '/',
            HTTP_HOST      => 'localhost',
        })->[2]->[0];
    };

    my $ret = $get->('/');
    chomp $ret;
    is( $ret, 'HOGE' );
}

done_testing;
