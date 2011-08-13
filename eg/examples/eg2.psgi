use strict;
use warnings;

use Hopen;

get '/' => sub { $_[0]->render('eg2.tt') };

hopen;
