package Klog::Controller::Log;
use strict;
use warnings;
use utf8;

use base 'Klog::Controller';
use Text::Caml;
use Data::Dumper;
use DBI;
use Encode;
use List::Util 'max', 'min';
use URI::Find;

sub uri_finder {
    my $self = shift;
    $self->{uri_finder} ||= URI::Find->new(sub { $self->replace_urls(@_) })
}

sub replace_urls {
    my $self = shift;
    my ($url) = @_;

    $self->render_template('url', url => $url);
}

sub prepare_highlights {
    my $self = shift;
    my ($hl) = @_;
    my @result;

    if ($hl) {
        @result = grep $_, split(',', $hl);
    }

    foreach (@result) {
        if (/^(\d+)\.\.(\d+)$/) {
            for ($1 .. $2) {
                $self->{hl}{$_} = 1;
            }
        }
        elsif (/^\d+$/) {
            $self->{hl}{$_} = 1;
        }
    }

    return sort { $a <=> $b } @result;
}

sub index {
    my $self = shift;
    my $env = $self->req;


    $self->{prev_nick} = '';

    $self->{start} = $env->param('skip');

    if (!$self->{start} || $self->{start} !~ /^\d+$/) {
        $self->{start} = 1;
    }

    my $chan = $env->param('chan') || 'ru.pm';
    $chan =~ s/\./_/g;

    $self->{show} = 40;

    my @hl_params = $self->prepare_highlights($env->param('hl'));
    my $min       = $hl_params[0];

    my $db = DBI->connect('DBI:mysql:database=irc_log;host=127.0.0.1',
        undef, undef, {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})
      or die;


    my ($tbl) = $db->selectrow_array(
        'SHOW TABLE STATUS WHERE NAME = ' . $db->quote('#' . $chan . "_log"));

    unless ($tbl) {
        $self->set_var(body => "This channel was never logged: #$chan");
        return;
    }

    my ($count) = $db->selectrow_array('SELECT COUNT(*) FROM `' . $tbl . '`');

    if (defined $min) {
        ($self->{start}) =
          $db->selectrow_array('SELECT COUNT(*) FROM `' 
              . $tbl
              . '` WHERE id > '
              . ($min + $self->{show} - 3));
    }

    $self->{start} = min $self->{start}, $count - $self->{show};
    $self->{start} = max $self->{start}, 1;

    my $data = $db->selectall_arrayref(
        'SELECT *, unix_timestamp(`time`) AS time_unix  FROM `' 
          . $tbl
          . '` ORDER BY `time` DESC, id DESC LIMIT ?, ?',
        {Slice => {}},
        $self->{start} - 1,
        $self->{show}
    );
    warn $db->errstr;
    my $body;

    for my $row (reverse @$data) {
        $body .= $self->render_message($row);
    }

    my $need_navbar;

    my $nav_param = {chan => $chan};
    if ($self->{start} > 1) {
        $nav_param->{next} = max $self->{start} - $self->{show}, 1;
        $need_navbar++;
    }

    if ($count > $self->{start} + $self->{show}) {
        $nav_param->{back} = $self->{start} + $self->{show};
        $need_navbar++;
    }

    my $navbar = '';

    if ($need_navbar) {
        $nav_param->{pos} = $self->{start};
        $navbar = $self->render_template('navbar', %$nav_param);
    }

    $self->set_var(body => $body, nav => $navbar);
}

sub render_navbar {
}

sub render_message {
    my $self = shift;
    my ($row) = @_;
    my $type = $row->{event};

    if ($type eq 'public')
      {
        if ($row->{nick} eq $self->{prev_nick}) {
            $type = 'public_repeat';
        }
        else {
            $type = 'public';
        }
        $self->{prev_nick} = $row->{nick};
    } else {
        $self->{prev_nick} = '';
    }


    my %params;

    if (exists $self->{hl}{$row->{id}}) {
        $params{class} = 'hl';
    }

    $params{qid} = $row->{id} - 2;

    @params{'date', 'time'} = split / /, $row->{'time'}, 2;

    if ($row->{event} eq 'public' && $row->{message}) {
        $row->{message} =~ s/&/&amp;/g;
        $row->{message} =~ s/</&lt;/g;
        $row->{message} =~ s/>/&gt;/g;
        $row->{message} =~ s/"/&quot;/g;
        $self->uri_finder->find(\$row->{message});
    }

    $self->render_template($type, %$row, %params)
}

1;
