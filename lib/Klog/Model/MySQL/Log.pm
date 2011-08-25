package Klog::Model::MySQL::Log;

use strict;
use warnings;

sub new { my $class = shift; bless {@_}, $class }

sub dbh { shift->{conn}->dbh }

=head2 get_page

    $self->get_page(
        channel => 'chan_name, start => $id, size => 100);

Returns hashref of log lines starting from start id with max size 'size'.

=cut

sub get_page {
    my $self = shift;
    my $params = ref $_[0] ? shift : {@_};

    my $channel = $params->{channel};
    unless (exists $self->{channels}{$channel}) {
        $self->{channels}{$channel} = $self->_channel_table_exists($channel);
    }

    my $table = $self->{channels}{$channel};
    return unless $table;

    my $conn = $self->{conn};

    # Lowlevel database actions
    $conn->run(
        sub {
            my $dbh = shift;

            my $data = $dbh->selectall_arrayref(
                "SELECT *, unix_timestamp(`time`) AS time_unix FROM $table
                 WHERE id >= ? ORDER BY `time` DESC, id DESC LIMIT ?",
                {Slice => {}}, $params->{start}, $params->{size}
            );
            return [reverse @$data];
        }
    );
}

sub _channel_to_table {
    my $self = shift;
    my ($chan) = @_;

    $chan = "#$chan" unless $chan =~ /^#/;
    $chan .= '_log';
}

sub _channel_table_exists {
    my $self = shift;
    my ($chan) = @_;

    if (exists $self->{channels}{$chan}) {
        return $self->{channels}{$chan};
    }

    my $conn = $self->{conn};
    $conn->run(
        sub {
            my $dbh = shift;

            my ($table) =
              $dbh->selectrow_array('SHOW TABLE STATUS WHERE NAME = ?',
                undef, $self->_channel_to_table($chan));

            return unless $table;

            return $self->{channels}{$chan} =
              $dbh->quote_identifier($table);
        }
    );
}

sub _create_table_for_channel {
    my $self   = shift;
    my ($chan) = @_;
    my $table  = $self->_channel_to_table($chan);

    if (exists $self->{channels}{$table}) { return 1 }

    my $conn = $self->{conn};
    $conn->run(
        sub {
            my $dbh = shift;

            my $qtable = $dbh->quote_identifier($table);

            $dbh->do("
                CREATE TABLE ${qtable} (
                    `id` int(10) unsigned NOT NULL auto_increment,
                    `time` timestamp NOT NULL default CURRENT_TIMESTAMP,
                    `nick` varchar(50) NOT NULL,
                    `sender` varchar(255) NOT NULL,
                    `message` text,
                    `event` varchar(10) NOT NULL default 'message',
                    `short` varchar(10) default NULL,
                    PRIMARY KEY  (`id`)
                ) DEFAULT CHARSET=utf8 COMMENT=?", undef, $table) or return;

            return $self->{channels}{$table} = $qtable;
        }
    );
}

sub write_event {
    my $self = shift;
    my ($line) = @_;

    # List of allowed events. Private should never became beallowed.
    unless ($line->{type} =~ /^(?:public|mode|quit|part|join|action|names)$/)
    {
        return 0;
    }

    my $table = $self->_channel_table_exists($line->{target});
    $table ||= $self->_create_table_for_channel($line->{target});

    if ($line->{type} eq 'mode') {
        return 0;

=head TODO 'mode' event has diferent parameters sequence. Make it works
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
=cut

    }

    my $conn = $self->{conn};
    $conn->run(
        sub {
            my $dbh = shift;
            my $query =
              "INSERT INTO $table (nick,sender,message,event) VALUES (?, ?, ?, ?)";

            my $result =
              $dbh->do($query, undef,
                @{$line}{qw/nickname sender message type/});

            if   ($result) { return 1 }
            else           { return 0 }
        }
    );
}

1;
