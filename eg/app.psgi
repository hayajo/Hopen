#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(readlink(__FILE__) || __FILE__), qw/.. extlib lib perl5/);
use lib File::Spec->catdir(dirname(readlink(__FILE__) || __FILE__), qw/.. lib/);

use Hopen;
use JSON;
use utf8;
use Try::Tiny;

# DB設定
set database => [
    'dbi:SQLite:/tmp/test.db',  # dsn
    '',                         # username
    '',                         # password
    {},                         # option
];
db->do(q{CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, name varchar, message TEXT)});

# テンプレート設定
set template => { path => 'app_tmpl' };

# ミドルウェア設定 - Plack::Middleware::* が利用できます
builder {
    enable 'Session', # 'Plack::Middleware'は省略可
        store => 'File';
    # subrequest で /static/... を利用する場合は、下で'Plack::Middleware::Static'を定義しなければならないので注意
    enable "ErrorDocument",
          500 => '/static/500.html',
          404 => '/static/404.html', subrequest => 1;
    enable 'HTTPExceptions';
    enable 'Static',
        path => qr{^/(favicon\.ico|static/)}, root => setting('base_dir');
    enable_if { $ENV{PLACK_ENV} eq 'development' } 'Debug'; # plackup のデフォルト PLACK_ENV は development なので注意
};

# 変数出力
get '/' => sub {
    my $req = shift;
    render('hello.tt', { time => time });
};

# 直出力
get '/raw' => sub {
    [
        200,
        ['Content-type' => 'text/plain; charset=utf-8'],
        [
            Encode::encode('utf8', 'こんにちは。世界。ブラウザの戻るボタンで戻ってください。')
        ],
    ];
};

# coderefをマッピングせずに出力を直接指定
# 文字コードを指定したい場合はrenderやmake_responseを利用すること
get '/basic_template' => 'basic.tt'; # テンプレート指定
get '/basic_str'      => [ 'ブラウザの戻るで戻ってください。' ]; # 文字列

# リダイレクト
get '/redirect' => sub {
    redirect('/');
};

# 文字エンコーディング指定
get '/encoding' => sub {
    render('encoding.tt', {}, encoding => 'shiftjis', content_type => 'text/html; charset=Shift_JIS');
};

# パラメータ出力
get '/params/:id' => sub {
    my ($req, $params) = @_;
    render('params.tt', { id => $params->{id} });
};

# パラメータ出力(正規表現)
get qr(/params-regexp/([^/]+)/(\w+)) => sub {
    my ($req, $params) = @_;
    render('params-regexp.tt', { user => $params->{splat}->[0], id => $params->{splat}->[1] });
};

# URLパラメータ出力
get '/url-params' => sub {
    my $req = shift;
    render('url-params.tt', { name => $req->param('name') });
};

# セッション
any ['GET', 'POST'], '/session' => sub {
    my $req     = shift;
    my $session = session($req);

    if (uc($req->method) eq 'POST' && (my $name = $req->param('name'))) {
        $session->set('name', $name);
        return redirect($req->uri);
    }

    render('session.tt', { name => $session->get('name') });
};

# クッキー
get '/cookies' => sub {
    my $req = shift;
    my $res = response(
        @{ render('cookies.tt', { cookies => $req->cookies }) }
    );
    if (my $value = $req->param('test_value')) {
        $res->cookies->{test_value} = $value;
    }
    $res->finalize;
};

# ファイルアップロード
any ['GET', 'POST'], '/upload' => sub {
    my $req     = shift;
    my $session = session($req);

    if (uc($req->method) eq 'POST' && $req->uploads->{uploaded}) {
        my $upload = $req->uploads->{uploaded};
        my $key    = Digest::SHA1::sha1_hex($upload->path);
        $session->set($key, {
            size         => $upload->size,
            path         => $upload->path,
            content_type => $upload->content_type,
            basename     => $upload->basename,
        });
        my $uri = $req->uri;
        $uri->query_form(file => $key);
        return redirect($uri->as_string);
    }

    my $params = { upload => undef };
    my $key    = $req->param('file');
    if ($key && (my $file_info = $session->get($key))) {
        $params->{upload} = $file_info;
    }
    render('upload.tt', $params);
};

# 外部テンプレート
get '/template' => sub {
    render('template.tt');
};

# データベース
any ['GET', 'POST'], '/db' => sub {
    my $req = shift;
    if (uc($req->method) eq 'POST') {
        my $txn = db->txn_scope;
        try { # transaction scope
            my $name    = $req->param('name');
            my $message = $req->param('message');
            db->do(
                q{INSERT INTO message (name, message) VALUES (?, ?)},
                {},
                $name, $message
            ) or die db->errstr;
            $txn->commit;
        } catch {
            $txn->rollback;
            die $_;
        };
        return redirect($req->uri->as_string);
    }

    my $rows = db->selectall_arrayref(
        q{SELECT name, message FROM message ORDER BY id DESC},
        { Slice => {} },
    );

    render('db.tt', { messages => $rows });
};

# JSON
get '/json' => sub {
    my $req = shift;
    my $data = JSON::to_json({
        time        => time,
        protocol    => $req->protocol,
        request_uri => $req->request_uri,
        address     => $req->address,
        method      => $req->method,
    }, { utf8 => 1 });

    # response(
    #     200,
    #     [ 'Content-Type' => 'application/json' ],
    #     [ $data ],
    # )->finalize;
    make_response(
        $data,
        content_type => 'application/json'
    );
};

# 例外処理
# 出力はbuilder内のP::M::ErrorDocument, P::M::HTTPException で処理される
get '/exception' => sub {
    my $req = shift;
    die 'throw exception';
};

hopen;

__DATA__

@@ hello.tt
[% WRAPPER "include/layout.tt" %]
<h2>変数出力</h2>
<p>こんにちは。世界。</p>
<p>time: [% time %]</p>
[% END %]

@@ basic.tt
[% WRAPPER "include/layout.tt" %]
<h2>coderefをマッピングせずに出力を直接指定</h2>
<p>お手軽出力</p>
[% END %]

@@ encoding.tt
[% WRAPPER "include/layout.tt" %]
<h2>文字エンコーディング指定</h2>
<p>このページはSJISだよ。</p>
[% END %]

@@ params.tt
[% WRAPPER "include/layout.tt" %]
<h2>パラメータ出力</h2>
<p>id: [% id %]</p>
[% END %]

@@ params-regexp.tt
[% WRAPPER "include/layout.tt" %]
<h2>パラメータ出力(正規表現)</h2>
<p>user: [% user %]</p>
<p>id: [% id %]</p>
[% END %]

@@ url-params.tt
[% WRAPPER "include/layout.tt" %]
<h2>URLパラメータ</h2>
<form action="#" method="get">
	<p>param:
	<input type="text" name="name" />
	<input type="submit" />
	</p>
</form>
[%- IF name -%]
<p>param value: [% name %]</p>
[%- END -%]
[% END %]

@@ session.tt
[% WRAPPER "include/layout.tt" %]
<h2>セッション</h2>
<form action="#" method="post">
	<p>store session:
	<input type="text" name="name" />
	<input type="submit" />
	</p>
</form>
<p>session stored value:
[%- IF name -%]
[% name %]
[%- END -%]
</p>
[% END %]

@@ cookies.tt
[% WRAPPER "include/layout.tt" %]
<h2>Cookie</h2>
<form action="#" method="get">
	<p>cookie value:
	<input type="text" name="test_value" />
	<input type="submit" />
	</p>
</form>
<div>
  <h3>cookies</h3>
  <dl id="cookies"></dl>
</div>
<script type="text/javascript">
  var cookies = (document.cookie) ? document.cookie.split(';') : new Array();
  var item = (cookies.length > 0) ? '' : 'no cookie';
  for (var i = 0; i < cookies.length; i++) {
      var v = cookies[i].split('=');
      item += '<dt>'+v[0]+'</dt><dd>'+v[1]+'</dd>';
  }
  document.getElementById('cookies').innerHTML = item;
</script>
[% END %]

@@ upload.tt
[% WRAPPER "include/layout.tt" %]
<h2>ファイルアップロード</h2>
<form action="#" method="post" enctype="multipart/form-data">
	<p>upload:
	<input type="file" name="uploaded" />
	<input type="submit" />
	</p>
</form>
[%- IF upload -%]
<div id="upload">
	<p>fileinfo</p>
	<ul>
		<li>size: [% upload.size %]</li>
		<li>path: [% upload.path %]</li>
		<li>content_type: [% upload.content_type %]</li>
		<li>basename: [% upload.basename %]</li>
	</ul>
</div>
[%- END -%]
[% END %]

@@ db.tt
[% WRAPPER "include/layout.tt" %]
<h2>データベース</h2>
<form action="#" method="post">
	<table>
		<tr><td style="text-align:right;">name:</td><td><input type="text" name="name" /></td></tr>
		<tr><td style="text-align:right;">message:</td><td><input type="text" name="message" /></td></tr>
		<tr><td colspan="2" style="text-align:right;"><input type="submit" /></td></tr>
	</table>
</form>
<div id="messages">
	<div>[% messages.size() %] messages</div>
[%- IF messages.size() -%]
	<ul style="list-style-type:none;padding:0;">
  [%- WHILE (item = messages.shift()) -%]
		<li>[% item.name %]: [% item.message %]</li>
  [%- END -%]
	</ul>
[%- END -%]
</div>
[% END %]
