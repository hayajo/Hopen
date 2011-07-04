#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(readlink(__FILE__) || __FILE__), qw/.. extlib lib perl5/);
use lib File::Spec->catdir(dirname(readlink(__FILE__) || __FILE__), qw/.. lib/);

use Hopen;

#builder {
#    enable 'Session', store => 'File';
#};

set template => { path => 'bench_tmpl' };

get '/' => sub {
    my $req = shift;
    render('hello.tt', { name => 'Hopen', title => 'Hello Hopen' });
};

hopen;

__DATA__

@@ hello.tt
<html><head><title>[% title %]</head><body>[DATA] Hello [% name %]!</body></html>
