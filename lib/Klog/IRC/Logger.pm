package Klog::IRC::Logger;

use warnings;
use strict;
require Carp;

use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( parse_user );

require Klog::Model;
require Klog::Config;
require Class::Load;

our $VERSION = 0.03;

sub new {
    my $class = shift;
    my $self  = {@_};

    return bless $self, $class;
}

sub _channels {
    my $self = shift;
    return $self->{channels} if $self->{channels};

    my $string = $self->{config}{channels};
    my @channels = grep $_, split /\s*,\s*/, $string;
    @channels = map { /^#/ ? $_ : "#$_" } @channels;

    $self->{channels} = \@channels;
}

sub PCI_register {
    my ($self, $irc) = @_;

    # Register events we are interested in
    $irc->plugin_register($self, 'SERVER',
        qw(public mode quit join part ctcp_action 353 001));

    $self->{SESSION_ID} =
      POE::Session->create(object_states => [$self => [qw(_start _shutdown)]])
      ->ID();

    return 1;
}

sub S_001 {
    my $self = $_[0];
    my $irc  = $_[1];

    print "Connected to ", $irc->server_name(), "\n";

    $irc->yield(join => $_) for @{$self->_channels};
    return 1;
}

sub _start {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $self->{SESSION_ID} = $_[SESSION]->ID();

    return;
}

sub _shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->alarm_remove_all();
    $kernel->refcount_decrement($self->{SESSION_ID}, __PACKAGE__);
}

sub PCI_unregister {
    my ($self, $irc) = @_;

    return 1;
}


sub S_public {
    my ($self, $irc) = splice @_, 0, 2;

    my $sender   = ${$_[0]};
    my $channels = ${$_[1]};
    my $msg      = ${$_[2]};

    # $_[2] contains list of channels, common for Klog and quitter.
    # But in strange format :\
    for my $chan (@{$channels}) {
        $self->Log('public', $chan, $sender, $msg);
    }

    # Return an exit code
    return PCI_EAT_NONE;
}

sub S_ctcp_action {
    my ($self, $irc) = splice @_, 0, 2;

    my ($sender, $chans, $msg) = @_;
    foreach my $ch (grep /^#/, @{${$chans}}) {
        $self->Log('action', $ch, ${$sender}, ${$msg});
    }
    return PCI_EAT_NONE;
}

sub S_quit {
    my ($self, $irc) = splice @_, 0, 2;
    my $sender = ${$_[0]};
    my $msg    = ${$_[1]};

    # list of channels that are common for bot and quitter
    for (@{${$_[2]}[0]}) {
        $self->Log('quit', $_, $sender, $msg);
    }
    return PCI_EAT_NONE;
}

# NAMES
sub S_353 {
    my ($self, $irc) = splice @_, 0, 2;
    my ($x, $raw, $message) = @_;

    my $chan = $$message->[1];

    unless (exists($irc->{'awaiting_names'}{$chan})
        && $irc->{'awaiting_names'}{$chan})
    {
        return PCI_EAT_NONE;
    }

    delete $irc->{'awaiting_names'}{$chan};

    $self->Log('names', $chan, 'server', $$message->[2]);

    PCI_EAT_NONE;
}

sub S_join {
    my ($self, $irc, $sender, $chan) = @_;
    my ($joiner, $user, $host) = parse_user($sender);

    $self->Log('part', ${$chan}, ${$sender});

    if ($joiner eq $irc->nick_name) {
        $irc->{'awaiting_names'}{$chan} = 1;
    }

    PCI_EAT_NONE;
}

sub S_part {
    my ($self, $irc, $sender, $chan, $msg) = @_;

    $self->Log('part', ${$chan}, ${$sender}, ${$msg});
}

sub S_mode {
    my ($self, $irc) = splice @_, 0, 2;
    my $user = ${$_[0]};
    my $chan = ${$_[1]};
    my $mode = ${$_[2]};
    my $arg  = $_[3];

# should me tested. Do we really need this check here
    if ($chan =~ /^#/) {
        $self->Log('mode', $chan, $user, $mode, $arg);
    }
    return PCI_EAT_NONE;
}

# Log takes event-type, channel and event-specific args
# and put it all into db
sub Log {
    my $self = shift;
    my $line = {};
    @{$line}{qw/type target sender message/} = splice @_, 0, 4;

    $line->{nickname} = parse_user($line->{sender});

    $self->{model}->write_event($line);
}

1;

__END__

=head1 NAME

POE::Klog - [One line description of module's purpose here]


=head1 SYNOPSIS

    use POE::Klog;


=head1 DESCRIPTION

POE::Klog

=head1 ATTRIBUTES

L<POE::Klog> implements following attributes:

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2011, Yaroslav Korshak.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
