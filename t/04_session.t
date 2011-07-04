use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    builder { enable 'Session', store => 'File' };
    get '/' => sub {
        session(shift)->set('file', __FILE__);
        'set session'
    };
    get '/sess' => sub {
        session(shift)->get('file');
    };
    hopen;
};

my $sess_key = '';
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
        HTTP_HOST      => 'localhost',
    });
    my $cookie   = { @{ $res->[1] } }->{'Set-Cookie'};
    my $expected = qr/(plack_session=[^;]+)/;
    like($cookie, $expected, 'Using session is ok');
    $sess_key = $1 if ($cookie =~ $expected);
}

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/sess',
        HTTP_HOST      => 'localhost',
        HTTP_COOKIE    => $sess_key,
    });
    chomp $res->[2]->[0];
    is($res->[2]->[0], __FILE__, 'Getting session value is ok');
}

done_testing;
