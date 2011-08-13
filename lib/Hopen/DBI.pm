package Hopen::DBI;

use parent qw/DBI/;

sub connect {
    my($class, $dsn, $user, $pass, $attr) = @_;
    $attr ||= { PrintError => 1, AutoCommit => 1, RaiseError => 0 };

    if ($dsn =~ /^dbi:SQLite:/) {
        $attr->{sqlite_unicode} = 1 unless exists $attr->{sqlite_unicode};
    } elsif ($dsn =~ /^dbi:mysql:/) {
        $attr->{mysql_enable_utf8} = 1 unless exists $attr->{mysql_enable_utf8};
    }

    my $dbh = $class->SUPER::connect($dsn, $user, $pass, $attr)
        or die "Cannot connect to server: $DBI::errstr";

    return $dbh;
}

package Hopen::DBI::db;

our @ISA = qw/DBI::db/;

use DBIx::TransactionManager;

sub _txn_manager {
    my $self = shift;
    if (!defined $self->{private_txn_manager}) {
        $self->{private_txn_manager} = DBIx::TransactionManager->new($self);
    }
    $self->{private_txn_manager};
}

sub txn_scope {
    $_[0]->_txn_manager->txn_scope(caller => [caller(0)]);
}

package Hopen::DBI::st;

our @ISA = qw/DBI::st/;

1;
