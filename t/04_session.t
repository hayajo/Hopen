use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    use Plack::Builder;
    load_plugins('Hopen::Plugin::Session');
    get '/' => sub {
        $_[0]->session->set('file', __FILE__);
        'set session';
    };
    get '/sess' => sub {
        $_[0]->session->get('file');
    };
    builder {
        enable 'Session', store => 'File';
        hopen;
    };
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
