package Klog::Model;

use strict;
use warnings;

use DBI;

sub new { my $class = shift; bless {@_}, $class }

sub builder {
    my $self = shift;
    return $self->{builder} if $self->{builder};

    Carp::croak("No config supplied") unless $self->{config};

    my $class  = $self->{config}{model}{model_namespace};

    Class::Load::load_class($class);

    my $config = $self->{config}{$class};

    $self->{builder} = $class->new(config => $config);
}

sub build {
    my $self = shift;
    my ($name) = @_;

    Carp::croak("Which model to build?") unless $name;

    $self->builder->build($name);
}

1;
