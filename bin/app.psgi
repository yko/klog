#!/usr/bin/env perl
use strict;
use warnings;
use Klog::Web;

my $app = Klog::Web->new;

$app->to_psgi;
