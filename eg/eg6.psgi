use Hopen;

# DB設定
set database => [
    'dbi:SQLite:/tmp/hopen.db',  # dsn
    '',                          # username
    '',                          # password
    {},                          # option
];
# db->do(q{CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, message TEXT)});

get '/' => sub {
    redirect('/list');
};

get '/list' => sub {
     my ($req) = @_;
     my $rows = db->selectall_arrayref(
         q{SELECT message FROM message ORDER BY id DESC},
         { Slice => {} },
     );
     render('list', { all => $rows });
};

hopen;

__DATA__

@@ list
[%- IF all.size() -%]
<ul>
  [%- WHILE (item = all.shift()) -%]
  <li>[% item.message %]</li>
  [%- END -%]
</ul>
[%- ELSE -%]
no messages
[%- END -%]
