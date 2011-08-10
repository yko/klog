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

    my $start = $env->param('skip');
    my $chan = $env->param('chan') || '#kiev.pm';
    $chan =~ s/\./_/g;

    my $min  = -1;
    my $show = 40;

    foreach (split(',', $env->param('hl'))) {
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
        undef, undef, {mysql_enable_utf8 => 1})
      or die;

    $start =~ /^\d+$/ or $start = 0;

    my ($tbl) = $db->selectrow_array(
        'SHOW TABLE STATUS WHERE NAME = ' . $db->quote($chan . "_log"));


    unless ($tbl) {
        print "This channel was never logged: $chan\n";
        exit(0);
    }

    my ($count) = $db->selectrow_array('SELECT COUNT(*) FROM `' . $tbl . '`');

    if ($min >= 0) {
        ($start) =
          $db->selectrow_array('SELECT COUNT(*) FROM `'
              . $tbl
              . '` WHERE id > '
              . ($min + $show - 3));
    }

    if ($start > $count - $show) {
        $start = $count - $show;
        if ($start < 0) { $start = 0 }
    }

    my $data = $db->selectall_arrayref(
        'SELECT *, unix_timestamp(`time`) AS time_unix  FROM `'
          . $tbl
          . '` ORDER BY `time` DESC, id DESC LIMIT ?, ?',
        {Slice => {}}, $start, $show
    );
    my $body;

    for my $row (reverse @$data) {
        $body .= $self->render_message($row);
    }

    $body = $self->render('index', body => $body);

    if (Encode::is_utf8($body)) {
        $body = Encode::encode('UTF-8', $body);
    }

    [200, ['Content-Type' => 'text/html'], [$body,]];
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
