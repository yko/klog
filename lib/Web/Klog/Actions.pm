package Web::Klog::Actions;
use strict;
use warnings;
use Text::Caml;
use Data::Dumper;
use DBI;
use Encode;
use utf8;

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub index {
    my $self = shift;
    my ($env) = @_;

    $self->{prev_nick} = '';


    my $self->{start} = $env->param('skip');

    if (!defined($self->{start}) || $self->{start} !~ /^\d+$/) {
        $self->{start} = 0;
    }

    my $chan = $env->param('chan') || '#ru.pm';
    $chan =~ s/\./_/g;

    my $min  = -1;
    $self->{show} = 40;

    my @hl_params;
    if (my $hl = $env->param('hl')) {
        @hl_params = split(',', $hl);
    }

    foreach (@hl_params) {
        if (/^(\d+)\.\.(\d+)$/) {
            for ($1 .. $2) {
                $self->{hl}{$_} = 1;
                $min = $min < 0 || $min > $_ ? $_ : $min;
            }
        }
        elsif (/^\d+$/) {
            $min = $min < 0 || $min > $_ ? $_ : $min;
            $self->{hl}{$_} = 1;
        }
    }

    my $db = DBI->connect('DBI:mysql:database=irc_log;host=127.0.0.1',
        undef, undef, {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})
      or die;


    my ($tbl) = $db->selectrow_array(
        'SHOW TABLE STATUS WHERE NAME = ' . $db->quote($chan . "_log"));

    unless ($tbl) {
        my $body = $self->render('index',
            body => "This channel was never logged: $chan");
        return [200, [], [$body]];
    }


    my ($count) = $db->selectrow_array('SELECT COUNT(*) FROM `' . $tbl . '`');

    if ($min >= 0) {
        ($self->{start}) =
          $db->selectrow_array('SELECT COUNT(*) FROM `' 
              . $tbl
              . '` WHERE id > '
              . ($min + $self->{show} - 3));
    }

    if ($self->{start} > $count - $self->{show}) {
        $self->{start} = $count - $self->{show};
        if ($self->{start} < 0) { $self->{start} = 0 }
    }

    my $data = $db->selectall_arrayref(
        'SELECT *, unix_timestamp(`time`) AS time_unix  FROM `' 
          . $tbl
          . '` ORDER BY `time` DESC, id DESC LIMIT ?, ?',
        {Slice => {}}, $self->{start}, $self->{show}
    );
    my $body;

    for my $row (reverse @$data) {
        $body .= $self->render_message($row);
    }

    my $need_navbar;

    my $nav_param = {};
    if ($self->{start} > 0) {
        $nav_param->{next} = $self->{start} > $sself->{how} ? $self->{start} - $self->{show} : 0;
        $need_navbar++;
    }

    if ($count > $self->{start} +  $self->{show}) {
        $nav_param->{back} = $self->{start} + $self->{show});
        $need_navbar++;
    }
    if ($need_navbar) {
        $nav_param->{pos} = $self->{start};
    }

    my $navbar =
      $need_navbar ? $self->render_template('navbar', %$nav_param) : '';

    $body = $self->render('index', body => $body, navbar => $navbar);

    my $content_type = 'text/html';
    if (Encode::is_utf8($body)) {
        $body = Encode::encode('UTF-8', $body);
        $content_type .= '; charset=utf-8'
          unless $content_type =~ /;\s*charset=/;
    }

    [200, ['Content-Type' => $content_type], [$body]];
}

sub render_navbar {
    my $
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

    $self->render_template($type, %$row, %params)
}

sub render {
    my $self = shift;
    my ($template) = shift;

    Carp::croak("Wrong arguments number") if @_ % 2;
    my %params = @_;

    my $content = $self->render_template($template, %params);

    my $result =
      $self->render_template('layout', %params, content => $content);

    $result;
}

sub render_template {
    my $self = shift;
    my $template = shift;

    my $renderer = $self->{renderer};
    my $result =
      $renderer->render_file('templates/' . $template . '.html.caml', @_);

    $result;
}

1;
