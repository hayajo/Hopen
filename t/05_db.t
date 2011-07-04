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
    set database => [
        'dbi:SQLite:'.$db_file,
        '',
        ''
    ];
    db->do(q{CREATE TABLE IF NOT EXISTS message (id INTEGER PRIMARY KEY, message TEXT)});
    get '/' => sub {
        for (my $i = 0; $i < @message; $i++) {
            my $txn = db->txn_scope;
            db->do(q{INSERT INTO message (message) VALUES (?)}, {}, $message[$i]);
            ( $i != $#message ) ? $txn->commit
                                : $txn->rollback;
        }
        my $rows = db->selectall_arrayref(q{SELECT message FROM message ORDER BY id DESC});
        join ',', ( map { $_->[0] } @$rows );
    };
    hopen;
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

done_testing;
