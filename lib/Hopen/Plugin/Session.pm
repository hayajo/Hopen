package Hopen::Plugin::Session;

sub init {
    my ($class, $c, $params) = @_;
    no strict 'refs';
    *{ "$c\::session" } = \&_session;
}

sub _session {
    my $self = shift;
    if (! $self->{session}) {
        Carp::croak 'Plack::Middleware::Session is disabled'
            unless ($self->req->env->{'psgix.session'});
        require Plack::Session;
        $self->{session} = Plack::Session->new($self->req->env);
    }
    $self->{session};
}

1;
