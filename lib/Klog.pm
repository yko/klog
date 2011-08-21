package Klog;

use warnings;
use strict;
require Carp;

use Plack::Builder;
use Routes::Tiny;
use Plack::Request;
use Klog::Controller;
use Text::Caml;
use FindBin;
use File::Spec;

use overload '&{}' => \&to_psgi;

our $VERSION = 0.03;

sub new {
    my $class = shift;
    my $self  = bless {@_}, $class;
    $self->{renderer} = Text::Caml->new;
    $self->{renderer}->set_templates_path('templates');

    $self->setup_routes;

    $self;
}

sub setup_routes {
    my $self = shift;

    return $self if $self->{routes};

    my $r = $self->{routes} = Routes::Tiny->new;

    $r->add_route('/', name => 'index', defaults => {controller => 'Log'});

    $self;
}

sub to_psgi {
    my $self = shift;
    builder {
        my $env = shift;

        $env->{'klog.renderer'} = $self->{renderer};

        enable 'Static' => path =>
          qr{\.(?:js|css|jpe?g|gif|ico|png|html?|swf|txt)$},
          root => File::Spec->catdir($FindBin::Bin, '..', 'htdocs');

        enable '+Klog::Middleware::Dispatcher',
          routes   => $self->{routes},
          renderer => $self->{renderer};

        enable 'ContentLength';

        $self->default($env);
    };
}

sub default {
    sub {
        [404, [], ["Not found"]];
    };
}

1;

__END__

=head1 NAME

Web::Klog - [One line description of module's purpose here]


=head1 SYNOPSIS

    use Web::Klog;


=head1 DESCRIPTION

Web::Klog

=head1 ATTRIBUTES

L<Web::Klog> implements following attributes:

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2011, Yaroslav Korshak.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
