#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use utf8;
use Encode;

plan tests => 6;

use_ok 'Klog::Model::MySQL';

my $config = {
    database    => 'test',
    driver_opts => 'mysql_enable_utf8=>1,mysql_auto_reconnect=>1'
};

my $model = Klog::Model::MySQL->new(config => $config);

ok $model->{dbh}, 'database connection created';

my $dbh = $model->{dbh};

BAIL_OUT("MySQL connection failed: " . DBI->errstr) unless $dbh;

my ($id) = $dbh->selectrow_array("SELECT CONNECTION_ID()");
like $id, qr/^\d+$/, "valid connection id";

ok $dbh->do('KILL ?', undef, $id), "kill MySQL connection";

my ($value) = $dbh->selectrow_array("SELECT 42;");

is $value, 42, "reconnected";

($value) = $dbh->selectrow_array("SELECT 'Привет мир!'");

ok Encode::is_utf8($value, 1),
  "return value has utf8 flag and contains well-formed UTF-8";
