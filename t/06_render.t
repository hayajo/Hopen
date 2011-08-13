use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/' => sub {
        $_[0]->render('index.tt');
    };
    get '/data' => sub {
        $_[0]->render('data.tt');
    };
    get '/str' => sub {
        $_[0]->render([ '[% param %]' ], { param => 'STR' });
    };
    get '/req' => sub {
        $_[0]->render('req.tt');
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
    $ret =~ s/[\r\n]//g;
    is( $ret, 'DATA' );

    $ret = $get->('/str');
    chomp $ret;
    is( $ret, 'STR' );

    my $path = '/req';
    $ret = $get->($path);
    chomp $ret;
    is( $ret, $path);

}

done_testing;

__DATA__

@@ data.tt
DATA

@@ req.tt
[% c().req.path %]
