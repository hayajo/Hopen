use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/' => 'index';
    hopen;
};

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
        HTTP_HOST      => 'localhost',
    });
    chomp $res->[2]->[0];
    is( $res->[2]->[0], 'Hello', 'Template rendering is OK');
}

done_testing;

__DATA__

@@ index
Hello
