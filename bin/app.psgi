#!/usr/bin/env perl
use strict;
use warnings;
use Klog;

my $app = Klog->new;

$app->to_psgi;
