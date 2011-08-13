use strict;
use warnings;
use inc::Module::Install;

name 'Hopen';
all_from 'lib/Hopen.pm';

requires 'Data::Section::Simple';
requires 'DBI';
requires 'DBIx::TransactionManager';
requires 'Data::OptList';
requires 'Plack';
requires 'Router::Simple';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';

build_requires 'Test::More';
test_requires 'DBD::SQLite';
test_requires 'Plack::Middleware::Session';
test_requires 'Test::Requires';
tests 't/*.t t/*/*.t';

WriteAll;
