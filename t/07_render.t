use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/' => sub {
        render('index.tt');
    };
    get '/data' => sub {
        render('data.tt');
    };
    get '/str' => sub {
        render([ '[% param %]' ], { param => 'STR' });
    };
    hopen;
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
    is( $ret, 'FILE' );

    $ret = $get->('/data');
    chomp $ret;
    is( $ret, 'DATA' );

    $ret = $get->('/str');
    chomp $ret;
    is( $ret, 'STR' );
}

done_testing;

__DATA__

@@ index.tt
DATA

@@ data.tt
DATA
