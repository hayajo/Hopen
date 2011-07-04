use Hopen;
use JSON;

get '/' => sub {
    redirect('/json');
};

get '/json' => sub {
     my ($req) = @_;
     my $json = JSON::to_json({
         foo => 'FOO',
         bar => 'BAR',
         buz => 'BUZ',
     });
     make_response($json, content_type => 'application/json');
};

hopen;
