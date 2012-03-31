#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Klog::Web;

my $app = Klog::Web->new( root_dir => "$Bin/.." );

$app->to_psgi;
