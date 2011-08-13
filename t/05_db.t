use strict;
use warnings;

use Test::More;

BEGIN { $ENV{PLACK_ENV} = 'development' }

my $db_file = File::Temp->new(
    UNLINK => 1,
    OPEN   => 0,
    EXLOCK => 0,
    SUFFIX => '.sqlite',
);

my @message = qw/hoge fuga piyo aaa/;

my $app = do {
    use Hopen;
    load_plugins('Hopen::Plugin::DBI');
    get '/' => sub {
        my $c = shift;
        $c->dbh->do(q{CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, message TEXT)});
        for (my $i = 0; $i < @message; $i++) {
            my $txn = $c->dbh->txn_scope;
            $c->dbh->do(q{INSERT INTO message (message) VALUES (?)}, {}, $message[$i]);
            ( $i != $#message ) ? $txn->commit
                                : $txn->rollback;
        }
        my $rows = $c->dbh->selectall_arrayref(q{SELECT message FROM message ORDER BY id DESC});
        join ',', ( map { $_->[0] } @$rows );
    };
    get '/rollback' => sub {
        my $c = shift;
        $c->dbh->do(q{DROP TABLE IF EXISTS message});
        $c->dbh->do(q{CREATE TABLE message (id INTEGER PRIMARY KEY, message TEXT)});
        $c->dbh->do(q{INSERT INTO message (message) VALUES (?)}, {}, 'FOO');

        my $txn = $c->dbh->txn_scope;
        for (my $i = 0; $i < @message; $i++) {
            $c->dbh->do(q{INSERT INTO message (message) VALUES (?)}, {}, $message[$i]);
        }
        $txn->rollback;
        my @row = $c->dbh->selectrow_array(q{SELECT count(id) FROM message ORDER BY id DESC});
        $row[0];
    };
    hopen('DBI' => ['dbi:SQLite:'.$db_file]);
};

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
        HTTP_HOST      => 'localhost',
    });
    chomp $res->[2]->[0];
    is($res->[2]->[0], join(',', reverse @message[0..$#message-1]), 'Getting db value is ok');
}

{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/rollback',
        HTTP_HOST      => 'localhost',
    });
    chomp $res->[2]->[0];
    is($res->[2]->[0], '1', 'Getting db value is ok');
}

done_testing;
