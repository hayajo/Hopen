use strict;
use warnings;

use Test::More;
use Data::Dumper;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $app = do {
    use Hopen;
    builder {
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                $env->{_middlewares} ||= [];
                push @{ $env->{_middlewares} }, 'HOGE';
                $app->($env);
            }
        };
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                $env->{_middlewares} ||= [];
                push @{ $env->{_middlewares} }, 'FUGA';
                $app->($env);
            }
        };
    };
    get '/' => sub {
        Data::Dumper->new( [ shift->env->{_middlewares} ] )->Terse(1)->Indent(0)->Dump();
    };
    hopen;
};

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
        HTTP_HOST      => 'localhost',
    });
    my $get = eval $res->[2]->[0];
    is_deeply($get, [ 'HOGE', 'FUGA' ]);
}

done_testing;
