use strict;
use warnings;

use File::Spec;
use File::Basename;
use Hopen;

get '/' => sub {
    my $c = shift;
    $c->render('hello.tt', { name => 'Hopen', title => 'Hello Hopen' });
};

hopen;
