package Klog::Web::Middleware::Dispatcher;

use strict;
use warnings;

use base 'Plack::Middleware';
use Try::Tiny;
use Encode;

require String::CamelCase;
require Class::Load;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $routes = $self->{routes};

    my $path   = $env->{PATH_INFO};
    my $method = $env->{REQUEST_METHOD};

    my $match = $routes->match($path, method => lc $method);
    return $self->app->($env) unless $match;

    $env->{'klog.req.match'} = $match;
    $self->render($env);
}
sub render {
    my $self = shift;
    my ($env) = @_;

    my $m          = $env->{'klog.req.match'};

    my $action     = $m->{name};
    my $controller = String::CamelCase::camelize($m->{params}{controller});
    my $namespace  = $m->{ns} || 'Klog::Web::Controller';

    my $class = $controller;
    unless ($class =~ s/^\+//) {
        substr $class, 0, 0, $namespace . '::';
    }

    my $result;
    try {
        Class::Load::load_class($class);

    }
    catch {
        $class =~ s{::}{/}g;

        die $_ unless $_ =~ m{^Can't locate $class\.pm in \@INC };
    };

    $result = $self->run_action($class, $action, $env);

    return $result if $result;

    $self->app->($env);
}

sub run_action {
    my $self = shift;
    my ($class, $action, $env) = @_;

    my $controller = $class->new(
        env            => $env,
        renderer       => $self->{renderer},
        models_factory => $self->{models_factory}
    );

    $controller->$action();

    if (!$controller->rendered) {
        return $self->render_env($controller, $action, $env);
    }

    return $controller->res->finalize;
}

sub render_env {
    my $self = shift;
    my ($controller, $action, $env) = @_;
    my $template = $controller->template || $action;

    my $body = $controller->render($action, $controller->vars);

    my $content_type = 'text/html';
    if (Encode::is_utf8($body)) {
        $body = Encode::encode('UTF-8', $body);
        $content_type .= '; charset=utf-8'
          unless $content_type =~ /;\s*charset=/;
    }
    $self->app->($env);
    return [200, ['Content-Type' => $content_type], [$body]];
}

1;
