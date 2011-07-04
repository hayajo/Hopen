package Hopen;

use strict;
use warnings;

our $VERSION = '0.01';

use Carp ();
use Data::Section::Simple ();
use DBI;
use DBIx::TransactionManager;
use Encode ();
use File::Basename qw/dirname/;
use File::Spec;
use Plack::Builder ();
use Plack::Request;
use Plack::Response;
use Plack::Util;
use Router::Simple;
use Scope::Container ();
use Text::Xslate;

my $_ROUTER   = Router::Simple->new;
my $_BUILDER  = sub {};
my $_CONFIG   = {};
my $_SETTINGS = {};
my ($_DATA, $_VIEW);

sub set { &setting(@_) }
sub setting {
    if (@_ == 1) {
        my $key = $_[0];
        my $val = $_SETTINGS->{ $key };
        return (defined $val) ? $val : $_CONFIG->{ $key }
    } elsif ( @_ > 1 ) {
        Carp::croak "Odd number in 'set' assignment"
                unless scalar @_ % 2 == 0;
        my $i = 0;
        while (my $key = shift) {
            $_SETTINGS->{ $key } = shift;
            $i++;
        }
        return $i;
    }
    return { %$_CONFIG, %$_SETTINGS };
}

sub get_data_section {
    my $data_section = $_DATA->get_data_section;
    map { chomp $data_section->{$_} } keys %$data_section;
    $data_section;
}

sub router2app {
    $_CONFIG = { @_ };
    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        set 'base_uri' => $req->base;
        if (my $p = $_ROUTER->match($env)) {
            my $code = $p->{action};
            if (ref $code eq 'CODE') {
                my %params = %$p;
                delete $params{action}; # TODO:
                my $res = &$code($req, \%params);
                return (ref $res eq 'ARRAY') ? $res
                                             : make_response($res);
            }
            render($code);
        } else {
            return [
                404,
                ['Content-Type' => 'text/plain'],
                ['not found'],
            ];
        }
    };
    Plack::Builder::builder {
        # perpetuation per-request.
        # via. Plack::Middleware::Scope::Container
        Plack::Builder::enable sub {
            my $app = shift;
            sub {
                my $container = Scope::Container::start_scope_container();
                $app->(shift);
            };
        };
        $_BUILDER->();
        $app;
    };
}

sub any {
    if (@_ == 3) {
        my ($methods, $pattern, $code) = @_;
        $_ROUTER->connect(
            $pattern,
            { action => $code },
            { method => [ map { uc $_ } @$methods ] },
        );
    } else {
        my ($pattern, $code) = @_;
        $_ROUTER->connect(
            $pattern,
            { action => $code },
        );
    }
}

sub get {
    any(['GET', 'HEAD'], $_[0], $_[1]);
}

sub post {
    any(['POST'], $_[0], $_[1]);
}

sub redirect {
    return [
        302,
        [ 'Location' => shift ],
        [],
    ]
}

sub builder(&) {
    my $block = shift;
    $_BUILDER = $block;
}

sub make_response {
    my ($body, %opts) = @_;
    [
        $opts{code} || 200,
        [ 'Content-Type' => $opts{content_type} || 'text/plain' ],
        [ Encode::encode($opts{encoding} || 'utf8', $body) ],
    ];
}

sub view {
    my $opts = { @_ };
    return $_VIEW if (defined $_VIEW);
    my $data_section = get_data_section();
    set 'template' => {
        'syntax' => 'TTerse',
        'module' => [ 'Text::Xslate::Bridge::TT2Like' ],
        'path'   => [ File::Spec->catdir(setting('base_dir'), 'views'), $data_section ],
        %{
            my $opts = setting('template') || {};
            if (exists $opts->{path}) { # relative-path convert to absolute-path
                my @path_abs = map { ref($_) ? $_ : File::Spec->rel2abs($_, setting('base_dir')) }
                    (ref($opts->{path}) eq 'ARRAY') ? @{ $opts->{path} } : $opts->{path};
                $opts->{path} = [ @path_abs, $data_section ];
            }
            $opts->{function} ||= {};
            $opts->{function}->{hopen_setting} = sub {
                my $key = shift;
                ($key) ? Hopen::setting($key) : Hopen::setting(); # read only
            };
            $opts;
        },
    };
    ( $_VIEW = Text::Xslate->new(setting('template')) );
}

sub render {
    my ($name, $vars, %opts) = @_;
    $vars ||= {};
    $vars->{hopen} = { %$_CONFIG, %$_SETTINGS };

    my $body;
    if (ref $name eq 'ARRAY') {
        $body = view->render_string($name->[0], $vars);
    } else {
        $body = view->render($name, $vars);
    }

    make_response(
        $body,
        content_type => 'text/html; charset=utf8',
        %opts
    );
}

sub db {
    # perpetuation per-request.
    if ( Scope::Container::in_scope_container
         && (my $dbh = Scope::Container::scope_container('hopen.db')) ) {
        return $dbh;
    }
    my ($dsn, $username, $password, $attr) = @_ || @{ setting('database') };
    $attr ||= { PrintError => 1, AutoCommit => 1, RaiseError => 0 };
    if ($dsn =~ /^dbi:SQLite:/) {
        $attr->{sqlite_unicode} = 1 unless exists $attr->{sqlite_unicode};
    } elsif ($dsn =~ /^dbi:mysql:/) {
        $attr->{mysql_enable_utf8} = 1 unless exists $attr->{mysql_enable_utf8};
    }
    my $dbh = DBI->connect($dsn, $username, $password, $attr);
    { # implement DBIx::TransactionManager::ScopeGuard features
        no strict 'refs';
        *{ ref($dbh) . '::_txn_manager'} = sub {
            my $self = shift;
            if (!defined $self->{private_txn_manager}) {
                $self->{private_txn_manager} = DBIx::TransactionManager->new($self);
            }
            $self->{private_txn_manager};
        };
        *{ ref($dbh) . '::txn_scope'} = sub {
            $_[0]->_txn_manager->txn_scope(caller => [caller(0)]);
        };
    }
    return (Scope::Container::in_scope_container)
        ? Scope::Container::scope_container('hopen.db', $dbh)
        : $dbh;
}

sub session {
    my $req = shift;
    Carp::croak 'Invalid argument'
            unless (ref($req) eq 'Plack::Request');
    Carp::croak 'Plack::Middleware::Session is disabled'
            unless ($req->env->{'psgix.session'});
    require Plack::Session;
    Plack::Session->new($req->env);
}

sub run {
    require Plack::Runner;
    my $runner = Plack::Runner->new;
    $runner->parse_options(@ARGV);
    $runner->run( &router2app(@_) );
}

sub run_as_cgi {
    require Plack::Handler::CGI;
    Plack::Handler::CGI->new->run( &router2app(@_) );
}

sub import {
    strict->import;
    warnings->import;

    no strict "refs";
    no warnings "redefine";

    my ($caller, $filename) = caller;
    set 'base_dir' => File::Spec->rel2abs(dirname($filename));
    $_DATA = Data::Section::Simple->new($caller);

    my @functions = qw/any get post redirect render session db set setting builder make_response/;
    for (@functions) {
        *{"${caller}\::$_"} = \&$_;
    }
    # import from Plack::Builder
    for (qw/enable enable_if/) {
        *{"${caller}\::$_"} = *{"Plack\::Builder\::$_"};
    }
    *{"${caller}::response"} = sub { Plack::Response->new(@_) };

    if ($ENV{'PLACK_ENV'}) {
        *{"${caller}\::hopen"} = \&router2app;
    } else {
        *{"${caller}\::hopen"} = sub { run(@_) };
        *{"${caller}\::hopen"} = sub { run_as_cgi(@_) }
            if $filename =~ /\.cgi$/;
    }
}

1;

__END__

=head1 NAME

Hopen - Plack based micro web application frameworks.

=head1 SYNOPSIS

In app.psgi

    use Hopen;
    builder { enable_if {$ENV{PLACK_ENV} eq 'development'} 'Debug' }; # != Plack::Builder::builder
    get '/' => sub { render('hello.tt', { time => time }) };
    hopen;

    __DATA__

    @@ hello.mt
    <h1>[% time %]: Hello World</h1>

Run app.psgi

    $ perl app.psgi

=head1 DESCRIPTION

Hopen is yet another micro web application framework
using Plack, Router::Simple, Text::Xslate, and DBI.

=head2 EXAMPLE

=head3 Using tepmlate in DATA section

    use Hopen;
    get '/' => 'index';
    hopen;

    __DATA__

    @@ index
    <h1>(DATA)Hello Hopen</h1>

=head3 Using tepmlate-file

in app.psgi

    use Hopen;
    get '/' => 'eg2.tt';
    hopen;

in view/eg2.tt

    <h1>(FILE)Hello Hopen</h1>

priority: FILE > DATA

=head3 Get params and give args to template

    use Hopen;

    get '/' => sub {
        my ($req) = @_;
        render('index', { name => $req->param('name') || 'anonymous' });
    };
    hopen;

    __DATA__

    @@ index
    <h1>Hello [% name %]</h1>

=head3 Handle post request and parse params from url path

    use Hopen;

    ...;

    get '/:name' => sub {
        my ($req, $args) = @_;
        my $name = $args->{name};
        ...;
    };

    ...;

=head3 Make custom response as JSON

    use Hopen;
    use JSON;

    ...;

    get '/json' => sub {
         my ($req) = @_;
         my $json = JSON::to_json({
             foo => 'FOO',
             bar => 'BAR',
             buz => 'BUZ',
         });
         make_response($json, content_type => 'application/json');
    };

    ...;

=head3 Using Model

DBI based.

    use Hopen;

    set database => [
        'dbi:SQLite:/tmp/hopen.db',  # dsn
        '',                          # username
        '',                          # password
        {},                          # option
    ];

    ...;

    get '/list' => sub {
         my ($req) = @_;
         my $rows = db->selectall_arrayref(
             q{SELECT body FROM message ORDER BY id DESC},
             { Slice => {} },
         );
         render('list', { all => $rows });
    };

    ...;

=head1 AUTHOR

Hayato Imai E<lt>hayajoE<gt>

=head1 SEE ALSO

L<Plack>, L<Router::Simple>, L<Text::Xslate>, L<DBI>

L<Mojolicious::Lite>, L<Dancer>, L<Hitagi|https://github.com/yusukebe/Hitagi>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
