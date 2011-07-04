use Hopen;

get '/' => sub {
    redirect('/hello/anonymous');
};

get '/hello/:name' => sub {
    my ($req, $args) = @_;
    my $name = $args->{name};
    render('hello', { name => $name });
};
hopen;

 __DATA__

@@ hello
<h1>Hello [% name %]</h1>
