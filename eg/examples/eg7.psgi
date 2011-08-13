use strict;
use warnings;

use Hopen;
use Plack::Builder;

load_plugins('Hopen::Plugin::Session');

any ['GET', 'POST'], '/' => sub {
     my $c = shift;
     if (uc($c->req->method) eq 'POST') {
         if ($c->req->param('regen') && $Plack::Middleware::Session::VERSION >= 0.13) {
             $c->session->options->{change_id}++; # supported P::M::Session >= 0.13
         }
         $c->session->set('value', $c->req->param('value'));
         return $c->redirect('/');
     }
     $c->render('index');
};

builder {
    enable 'Session', store => 'File';
    hopen;
};

__DATA__

@@ index
<form action="/" method="post">
  session value<br/>
  <input name="value" type="text" />
  <label><input type="checkbox" name="regen" value="1"/>regenerate session</label>
  <br/>
  <input type="submit" />
</form>
<hr/>
<dl>
  <dt>session_id</dt>
  <dd>[% c().session.id %]</dd>
  <dt>value</dt>
  <dd>[% c().session.get('value') %]</dd>
</dl>
