use strict;
use warnings;

use Hopen;
use JSON;

get '/' => '<a href="/json">download json</a>';

get '/json' => sub {
     my $c = shift;
     my $json = JSON::to_json({
         foo => 'FOO',
         bar => 'BAR',
         buz => 'BUZ',
     });
     $c->render(
         [ $json ],
         {},
         headers => [ 'Content-Type' => 'application/json' ],
     );
};

hopen;
