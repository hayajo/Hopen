use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/' => 'Hello';
    get '/code' => sub { 'Hello' };
    hopen;
};

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
        HTTP_HOST      => 'localhost',
    });
    chomp $res->[2]->[0];
    is( $res->[2]->[0], 'Hello');

    $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/code',
        HTTP_HOST      => 'localhost',
    });
    chomp $res->[2]->[0];
    is( $res->[2]->[0], 'Hello');
}

done_testing;
