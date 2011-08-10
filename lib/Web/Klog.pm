package Web::Klog;

use warnings;
use strict;
require Carp;

use Plack::Builder;
use Routes::Tiny;
use Plack::Request;
use Web::Klog::Actions;
use Text::Caml;
use FindBin;
use File::Spec;

use overload '&{}' => \&to_psgi;

our $VERSION = 0.03;

sub new {
    my $class = shift;
    my $self  = bless {@_}, $class;
    $self->{renderer} = Text::Caml->new;

    my $r     = $self->{routes} = Routes::Tiny->new;

    $r->add_route('/', name => 'index');

    $self;
}

sub to_psgi {
    my $self = shift;
    builder {
        my $env = shift;
        enable 'Static' => path =>
          qr{\.(?:js|css|jpe?g|gif|ico|png|html?|swf|txt)$},
          root => File::Spec->catdir($FindBin::Bin, '..', 'htdocs');

        enable sub {
            my $app = shift;

            sub {
                my $env    = shift;
                my $path   = $env->{PATH_INFO};
                my $method = $env->{REQUEST_METHOD};

                my $m = $self->{routes}->match($path, method => lc $method);
                warn "No route " unless $m;
                return $app->($env) unless $m;

                my $action_method = $m->{name};
                if (Web::Klog::Actions->can($action_method)) {
                    my $action =
                      Web::Klog::Actions->new(renderer => $self->{renderer});
                    my $request = Plack::Request->new($env);
                    return $action->$action_method($request);
                }

                return $app->($env);
            };
        };

        enable 'ContentLength';

        $self->default($env);
    };
}

sub default {
    sub {
                warn " Got nothing";
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
