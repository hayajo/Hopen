use strict;
use warnings;

use Hopen;

get '/' => sub {
    my $c = shift;
    $c->render('index', { name => $c->req->param('name') || 'anonymous' });
};

hopen;

 __DATA__

@@ index
<h1>Hello [% name %]</h1>
<form action="/">
  name:<br />
  <input name="name" type="text" />
  <input type="submit" />
</form>

