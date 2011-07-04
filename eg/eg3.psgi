use Hopen;

get '/' => sub {
    my ($req) = @_;
    render('index', { name => $req->param('name') || 'anonymous' });
};
hopen;

 __DATA__

@@ index
<h1>Hello [% name %]</h1>
