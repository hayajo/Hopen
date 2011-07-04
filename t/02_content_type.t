use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    get '/xml' => sub {
        render(
            'xml',
            {},
            content_type => 'application/xml'
        );
    };
    hopen;
};

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/xml',
        HTTP_HOST      => 'localhost',
    });

    is_deeply(
        $res,
        [
            200,
            [ 'Content-Type' => 'application/xml' ],
            [ '<xml><root>content</root></xml>' ],
        ],
        'Hnadling XML content type is OK');
}

done_testing;

__DATA__

@@ xml
<xml><root>content</root></xml>
