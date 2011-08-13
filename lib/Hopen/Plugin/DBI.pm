package Hopen::Plugin::DBI;

use Hopen::DBI;

sub init {
    my ($class, $c, $params) = @_;
    no strict 'refs';
    *{ "$c\::dbh" } = \&_dbh;
}

sub _dbh {
    my $self = shift;
    if (! $self->{dbh}) {
        my $conf = $self->config->{DBI}
            or die "no configureation 'DBI'";
        $self->{dbh} = Hopen::DBI->connect(@$conf);
    }
    $self->{dbh};
}

1;
