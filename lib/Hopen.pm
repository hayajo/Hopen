package Hopen;

use strict;
use warnings;
use 5.008_001;
our $VERSION = '0.04';

use Carp ();
use Data::OptList;
use Data::Section::Simple ();
use File::Basename qw/dirname/;
use File::Spec;
use Plack::Request;
use Router::Simple;
use Text::Xslate;

my $_COUNTER;

{
    our $_CONTEXT; # localize this variable per request
    sub context { $_CONTEXT }
}

sub import {
    strict->import;
    warnings->import;

    no strict "refs";

    my $router = Router::Simple->new();
    my ($caller, $filename) = caller;

    my $base_class = __PACKAGE__.'::__child__'.$_COUNTER++;
    {
        no warnings;
        unshift @{ "$base_class\::ISA" }, (__PACKAGE__, 'Hopen::Context');
        unshift @{ "$caller\::ISA" }, $base_class;
    }

    my $base_dir = File::Spec->rel2abs( dirname($filename) );
    *{ "$caller\::base_dir" } = sub { $base_dir };

    *{ "$caller\::router" } = sub { $router };

    *{ "$caller\::any" } = sub {
        if (@_ == 3) {
            my ($methods, $pattern, $code) = @_;
            $router->connect(
                $pattern,
                { __code => $code },
                { method => [ map { uc $_ } @$methods ] },
            );
        } else {
            my ($pattern, $code) = @_;
            $router->connect( $pattern, { __code => $code } );
        }
    };
    *{ "$caller\::get" } = sub {
        $router->connect($_[0], {__code => $_[1]}, {method => ['GET','HEAD']});
    };
    *{ "$caller\::post" } = sub {
        $router->connect($_[0], {__code => $_[1]}, {method => ['POST']});
    };

    *{ "$caller\::load_plugins" } = sub {
        my @args = @_;
        for my $opt (@{ Data::OptList::mkopt(\@args) }) {
            my ($module, $params) = ($opt->[0], $opt->[1]);
            $module = Plack::Util::load_class($module);
            $module->init($caller, $params);
        }
    };

    *{ "${base_class}\::config" } = sub {
        my $class = shift;
        my %config = (@_ == 1) ? %{$_[0]} : @_;
        no warnings 'redefine';
        *{"$caller\::config"} = sub { \%config };
        \%config;
    };

    *{ "$caller\::hopen" } = sub {
        $caller->config(@_);
        my $app = sub {
            my $env = shift;
            my $req = Plack::Request->new($env);
            my $self = $caller->new($req);
            no warnings 'redefine';
            local $Hopen::_CONTEXT = $self;
            my $res;
            if (my $p = $router->match($env)) {
                my $code = $p->{__code};
               $res = (ref $code eq 'CODE') ? &$code($self, $p)
                                            : $self->render([ $code ]);
                unless (Scalar::Util::blessed($res) && $res->isa('Plack::Response'))  {
                    $res = $self->render([ $res ]);
                }
            } else {
                $res = $self->res_404;
            }
            return $res->finalize;
        };
        $app;
    };

    *{ "${base_class}\::view" } = sub {
        my $vpath = Data::Section::Simple->new($caller)->get_data_section() || +{};
        my $config = $caller->config->{'Text::Xslate'} || +{};
        my $xs_opts = +{
            'syntax' => 'TTerse',
            'module' => [ 'Text::Xslate::Bridge::TT2Like' ],
            'path'   => [ $vpath, File::Spec->catdir($caller->base_dir, 'views') ],
            'function' => {},
            %$config,
        };
        $xs_opts->{function}->{c} = sub { Hopen->context() };
        my $xs = Text::Xslate->new($xs_opts);
        no warnings 'redefine';
        *{ "$caller\::view" } = sub { $xs };
        $xs;
    };

}

package Hopen::Context;

use Encode ();

sub new {
    my ($class, $req) = @_;
    Carp::croak '$req is required'
        unless defined $req && ref($req) eq 'Plack::Request';
    bless {
        encoding => 'utf-8',
        req      => $req,
    }, ref $class || $class;
}

sub view { die "This is abstract method: view" }
sub config { die "This is abstract method: config" }

sub encoding {
    my $self = shift;
    $self->{encoding} = shift if (@_);
    $self->{encoding};
}

sub request { $_[0]->{req} }
sub req     { $_[0]->{req} }

sub create_response { shift->req->new_response(@_) }

sub redirect {
    my ($self, $url, $status) = @_;
    my $res = $self->create_response;
    $res->redirect($url, $status);
    return $res;
}

sub res_404 {
    my $self = shift;
    $self->create_response(
        404,
        { 'Content-Type' => 'text/plain' },
        "not found"
    );
}

sub render {
    my $self = shift;
    my ($tmpl, $vars, %opts) = @_;

    my $body = (ref $tmpl eq 'ARRAY')
        ? $self->view->render_string($tmpl->[0], $vars)
        : $self->view->render($tmpl, $vars);

    $self->create_response(
        $opts{status} || 200,
        $opts{headers} || { 'Content-Type' => 'text/html; charset=' . $self->encoding },
        $self->encode_body($body),
    );
}

sub encode_body {
    my ($self, $body) = @_;
    ($self->encoding) ? Encode::encode($self->encoding, $body) : $body;
}

1;

__END__

=head1 NAME

Hopen - Plack based micro web application frameworks.

=head1 SYNOPSIS

    use strict;
    use warnings;

    use Hopen;

    get '/' => sub {
        my $c = shift;
        $c->render('index', { name => $c->req->param('name') || 'anonymous' });
    };

    hopen;

     __DATA__

    @@ index
    <h1>Hello [% name %]</h1>
    <form action="/">
      name:<br />
      <input name="name" type="text" />
      <input type="submit" />
    </form>

=head1 DESCRIPTION

Hopen is yet another micro web application framework
using Plack, Router::Simple, Text::Xslate.

=head2 EXAMPLE

=head3 Using tepmlate in DATA section

    use Hopen;
    get '/' => sub { $_[0]->render('index') };
    hopen;

    __DATA__

    @@ index
    <h1>Hello Hopen</h1>

=head3 Using tepmlate-file

in app.psgi


    use strict;
    use warnings;

    use Hopen;

    get '/' => sub { $_[0]->render('eg2.tt') };

    hopen;

in views/eg2.tt

    <h1>Hello Hopen</h1>

priority: DATA > FILE

=head3 Get params and give args to template

    use strict;
    use warnings;

    use Hopen;

    get '/' => sub {
        my $c = shift;
        $c->render('index', { name => $c->req->param('name') || 'anonymous' });
    };

    hopen;

     __DATA__

    @@ index
    <h1>Hello [% name %]</h1>
    <form action="/">
      name:<br />
      <input name="name" type="text" />
      <input type="submit" />
    </form>

=head3 Handle post request and parse params from url path

    use strict;
    use warnings;

    use Hopen;
    use Text::Xslate qw/uri_escape/;

    get '/' => sub {
        my $c = shift;
        my $name = $c->req->param('name') || 'anonymous';
        $c->redirect('/hello/'.uri_escape($name));
    };

    get '/hello/:name' => sub {
        my ($c, $args) = @_;
        my $name = $args->{name};
        $c->render('hello', { name => $name });
    };

    hopen;

    __DATA__

    @@ hello
    <h1>Hello [% name %]</h1>
    <form action="/">
      name:<br />
      <input name="name" type="text" />
      <input type="submit" />
    </form>

=head3 Make custom response as JSON


    use strict;
    use warnings;

    use Hopen;
    use JSON;

    get '/' => '<a href="/json">download json</a>';

    get '/json' => sub {
         my $c = shift;
         my $json = JSON::to_json({
             foo => 'FOO',
             bar => 'BAR',
             buz => 'BUZ',
         });
         $c->render(
             [ $json ],
             {},
             headers => [ 'Content-Type' => 'application/json' ],
         );
    };

    hopen;

=head3 Using Session

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

=head3 Using Model

DBI based.

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

=head1 AUTHOR

Hayato Imai E<lt>hayajoE<gt>

=head1 SEE ALSO

L<Plack>, L<Router::Simple>, L<Text::Xslate>, L<DBI>

L<Amon2::Lite>, L<Mojolicious::Lite>, L<Dancer>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
