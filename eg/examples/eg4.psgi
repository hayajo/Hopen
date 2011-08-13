use strict;
use warnings;

use Hopen;
use Text::Xslate qw/uri_escape/;

get '/' => sub {
    my $c = shift;
    my $name = $c->req->param('name') || 'anonymous';
    $c->redirect('/hello/'.uri_escape($name));
};

get '/hello/:name' => sub {
    my ($c, $args) = @_;
    my $name = $args->{name};
    $c->render('hello', { name => $name });
};

hopen;

__DATA__

@@ hello
<h1>Hello [% name %]</h1>
<form action="/">
  name:<br />
  <input name="name" type="text" />
  <input type="submit" />
</form>
