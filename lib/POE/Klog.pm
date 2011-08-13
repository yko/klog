package POE::Klog;

use warnings;
use strict;
require Carp;

use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::IRC::Common qw( parse_user );
use DBI;

our $VERSION = 0.03;

sub new {
    my $self  = {};
    my $class = shift;
    $self->{'params'} = {
        'db_host'   => 'localhost',
        'db_port'   => '3306',
        'db_driver' => 'mysql',
        @_
    };

    return bless $self, $class;
}

# Required entry point for PoCo-POE
sub PCI_register {
    my ($self, $irc) = @_;

    # Register events we are interested in
    $irc->plugin_register($self, 'SERVER',
        qw(public mode quit join part ctcp_action 353));
    $self->{SESSION_ID} =
      POE::Session->create(object_states => [$self => [qw(_start _shutdown)]])
      ->ID();

    # Return success
    return 1;
}

sub _start {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $self->{SESSION_ID} = $_[SESSION]->ID();


    # Connectind DB
    $self->{'db'} = DBI->connect(
        'DBI:'
          . $self->{'params'}{'driver'}
          . ':database='
          . $self->{'params'}{'database'}
          . ';host='
          . $self->{'params'}{'host'},
        @{$self->{'params'}}{qw/user password/},
        {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1}
    );

    unless ($self->{'db'}) { die "Uneable connect db: " . $DBI::errstr }

# caching already logged channels
# real channel name stored in table Comment field.

    my $sth = $self->{'db'}->prepare('show table status like "%_log"') || die;
    $sth->execute || die;

    while (my $tbl = $sth->fetchrow_hashref) {

# InnoDB also store some information in comments
# after ';'. Remove it
# klog don't need foreign secrets
        my ($name) = split /;/, $tbl->{'Comment'}, 2;
        $self->{$name} = $tbl->{'Name'};
    }

    return;
}

sub _shutdown {
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->alarm_remove_all();
    $kernel->refcount_decrement($self->{SESSION_ID}, __PACKAGE__);

# Does it work? dunno...
    $self->{'db'}->disconnect();
    return;
}

# Required exit point for PoCo-POE
sub PCI_unregister {
    my ($self, $irc) = @_;
    $poe_kernel->call($self->{SESSION_ID} => '_shutdown');
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

# список каналов, общих для бота и уходящего
    for (@{${$_[2]}[0]}) {
        $self->Log('quit', $_, $sender, $msg);
    }
    return PCI_EAT_NONE;
}

# join and part (and, possibly, quit) are simirar
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
    my ($self, $irc) = @_;
    my ($joiner, $user, $host) = parse_user(${$_[2]});
    my $chan = ${$_[3]};

    unshift @_, 'join';
    &jp;

    if ($joiner eq $irc->nick_name) {
        $irc->{'awaiting_names'}{$chan} = 1;
    }

    PCI_EAT_NONE;
}

sub S_part { unshift @_, 'part'; &jp }

sub jp {
    my ($event, $self, $irc) = splice @_, 0, 3;
    my ($sender, $chan, $msg) = @_;

# but there is some diff
    $self->Log($event, ${$chan}, ${$sender},
        $event ne 'join' ? ${$msg} : undef);
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
    my ($self, $type, $target) = splice @_, 0, 3;

    if ($type =~ /^(?:public|mode|quit|part|join|action|names)$/) {
        $target = join('_', $target, 'log');
    }
    unless (exists $self->{$target}) {

# Ah! Defloration!
        $self->create_tbl($target) || die $DBI::errstr;
    }


    if ($type =~ /^(?:public|quit|part|join|action|names)$/) {
        my $sender   = shift;
        my $nickname = parse_user($sender);
        my $query =
            'INSERT INTO `'
          . $self->{$target}
          . '` (nick,sender,message,event) VALUES 
      ('
          . join(',',
            map { $self->{'db'}->quote($_) } $nickname,
            $sender, $_[0], $type)
          . ')';
        $self->{'db'}->do($query) || warn $DBI::errstr;
    }
    elsif ($type eq 'mode') {
        my $sender   = shift;
        my $nickname = parse_user($sender);
        my $query =
            'INSERT INTO `'
          . $self->{$target}
          . '` (nick,sender,`short`,message,event) VALUES 
      ('
          . join(',',
            map { $self->{'db'}->quote($_) } $nickname,
            $sender, $_[0], join(' ', @{$_[1]}))
          . ',"mode")';
        $self->{'db'}->do($query) || die $DBI::errstr;
    }
    return 1;
}

# Create default log-table.
sub create_tbl {
    my ($self, $tbl) = @_;
    if (exists $self->{$tbl}) { return 1 }
    my $tbln = $tbl;
    $tbln =~ s/\./_/g;

    $self->{'db'}->do(
        "CREATE TABLE  `${tbln}` (
    `id` int(10) unsigned NOT NULL auto_increment,
    `time` timestamp NOT NULL default CURRENT_TIMESTAMP,
    `nick` varchar(50) NOT NULL,
    `sender` varchar(255) NOT NULL,
    `message` text,
    `event` varchar(10) NOT NULL default 'message',
    `short` varchar(10) default NULL,
    PRIMARY KEY  (`id`)
   ) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8 COMMENT="
          . $self->{'db'}->quote($tbl) . ";"
    ) || return 0;
    return $self->{$tbl} = $tbln;
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
