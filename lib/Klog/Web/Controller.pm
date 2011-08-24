package Klog::Web::Controller;
require File::Spec;
require Class::Load;

sub new {
    my $class = shift;
    bless ref $_[0] ? $_[0] : {@_}, $class;
}

sub env { shift->{env}; }

sub params {
    shift->{env}->{'klog.req.match'}->{params};
}
sub req {
    my $self = shift;

    $self->{req} ||= Plack::Request->new($self->env);
}

sub template {
    shift->{template};
}


sub res {
    my $self = shift;

    $self->{res} ||= $self->req->new_response;
}

sub set_var {
    my $self = shift;

    for (my $i = 0; $i < @_; $i += 2) {
        $self->env->{'klog.vars'}->{$_[$i]} = $_[$i + 1];
    }

    $self;
}

sub vars {
    shift->env->{'klog.vars'} ||= {};
}

sub set_layout {
    my $self = shift;
    $self->env->{'klog.layout'} = shift;

    $self;
}

sub render {
    my $self = shift;
    my ($template) = shift;

    my $params;
    if (ref $_[0]) {
        $params = shift;
    }
    else {
        Carp::croak("Wrong arguments number") if @_ % 2;
        $params = {@_};
    }

    my $content = $self->render_template($template, $params);
    my $template = $self->env->{'klog.layout'} // 'layout';

    my $result =
      $self->render_template($template, %$params, content => $content);

    $result;
}

sub render_template {
    my $self     = shift;
    my $template = shift;

    my $renderer = $self->{renderer};

    my $file = $template . '.html.caml';
    $renderer->render_file($file, @_);
}

sub rendered {
    my $self = shift;
    return unless $self->{res};
    $self->{res}->code || $self->{res}->body;
}

sub model {
    my $self = shift;
    my ($name) = @_;
    unless ($name) {
        my $namespace = __PACKAGE__;
        $name = ref $self;
        $name =~ s/^\Q$namespace\E:://;
    }

    if (exists $self->{models}{$name}) {
        return $self->{models}{$name};
    }

    $self->{models}{$name} ||= $self->{models_factory}->($name);
}

1;
