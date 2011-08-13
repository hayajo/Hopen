use strict;
use warnings;

use Hopen;
use File::Temp qw/tempfile/;

my $conn_info = [
    'dbi:SQLite:'.[ tempfile() ]->[1],
];

{ # prepare
    my $dbh = Hopen::DBI->connect(@$conn_info);
    $dbh->do(q{CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, message TEXT)});
}

load_plugins('Hopen::Plugin::DBI');

get '/' => sub {
     my $c = shift;
     my $rows = $c->dbh->selectall_arrayref(
         q{SELECT message FROM message ORDER BY id DESC},
         { Slice => {} },
     );
     $c->render('list', { all => $rows });
};

post '/edit' => sub {
    my $c = shift;
    if (my $msg = $c->req->param('message')) {
        $c->dbh->do(
            q{INSERT INTO message (message) VALUES (?)},
            {},
            $msg,
        );
    }
    $c->redirect('/list');
};

hopen( 'DBI' => $conn_info );

__DATA__

@@ list
<form action="/edit" method="post">
  message<br/>
  <input name="message" type="text" />
  <input type="submit" />
</form>
<hr/>
[%- IF all.size() -%]
<ul>
  [%- WHILE (item = all.shift()) -%]
  <li>[% item.message %]</li>
  [%- END -%]
</ul>
[%- ELSE -%]
no messages
[%- END -%]
