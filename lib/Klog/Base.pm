package Klog::Base;

require Klog::Config;

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub config {
    my $self = shift;
    $self->{config} ||= Klog::Config->load;
}

1;
