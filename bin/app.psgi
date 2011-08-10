#!/usr/bin/env perl
use strict;
use warnings;
use Web::Klog;

my $app = Web::Klog->new;

$app->to_psgi;
