package Klog::IRC;

use strict;
use warnings;

use base 'Klog::Base';

require Klog::IRC::Logger;
require Klog::Model;
require POE::Component::IRC::State;
use POE;

sub spawn {
    my $self = ref $_[0] ? shift : shift->new;
    my $config = $self->config->{irc};

    my $irc = POE::Component::IRC::State->spawn(
        nick    => $config->{nickname},
        ircname => $config->{name} || $config->{nickname},
        server  => $config->{server},
        port    => $config->{port} || 6667,
    ) or die "Oh noooo! $!";

    $self->register_plugins($irc);
    POE::Session->create(
        package_states => ['Klog::IRC' => [qw(_start)]],
        heap           => {irc  => $irc, config => $config},
    );
}

sub _start {
    my $heap = $_[HEAP];
    my $irc = $heap->{irc};

    $irc->yield(register => 'all');
    $irc->yield(connect  => {});

    return;
}

sub register_plugins {
    my $self = shift;
    my ($irc) = @_;
    my $config = $self->config->{irc};

    $irc->plugin_add('Logger',
        Klog::IRC::Logger->new(model => $self->model, config => $config));

    if ($config->{console}) {
        require POE::Component::IRC::Plugin::Console;
        my $plug = POE::Component::IRC::Plugin::Console->new(
            bindport => $config->{console_port},
            password => $config->{console_pass}
        );
        $irc->plugin_add('Console' => $plug);
    }

    if ($config->{reconnect_tries}) {
        require POE::Component::IRC::Plugin::Connector;
        my $plug =
          POE::Component::IRC::Plugin::Connector->new(
            reconnect => $config->{reconnect_tries});
        $irc->plugin_add(Connector => $plug);
    }

    if ($config->{cycle_empty}) {
        require POE::Component::IRC::Plugin::CycleEmpty;
        my $plug = POE::Component::IRC::Plugin::CycleEmpty->new;
        $irc->plugin_add(CycleEmpty => $plug);
    }
}

sub model {
    my $self = shift;
    $self->{model}
      ||= Klog::Model->new(config => $self->config)->build('Log');
}

1;
