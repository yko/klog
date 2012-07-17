package Klog::Web::Controller::Log;
use strict;
use warnings;

use base 'Klog::Web::Controller';
use Text::Caml;
use DBI;
use Encode;
use List::Util 'max', 'min';
use URI::Find;

sub index {
    my $self = shift;
    my $env = $self->req;

    $self->{prev_nick} = '';

    my $chan = $self->params->{chan} || $env->param('chan') || 'ru.pm';

    # TODO: Make configurable
    $self->{show} = 40;

    my @hl_params = $self->prepare_highlights($env->param('hl'));

    my %params = (channel => $chan, size => 40);
    $params{start} = $env->param('start');;
    if (!$params{start} || $params{start} !~ /^\d+$/) {
        delete $params{start};
    }
    if (@hl_params) {
        $params{start} ||= $hl_params[0] - 3;
        $params{start} = min $hl_params[0] - 3, $params{start};
        $params{start} = max $params{start}, 1;
    }

    my $data = $self->model->get_page(%params);

    unless ($data) {
        $self->set_var(body => "This channel was never logged: #$chan");
        return;
    }

    my $body;

    for my $row (@$data) {
        $body .= $self->render_message($row);
    }

    $params{chan} = $chan;
    $params{data} = $data;

    my $navbar = $self->render_navbar(\%params);

    $self->set_var(body => $body, nav => $navbar);
}

sub render_navbar {
    my $self = shift;
    my ($params) = @_;

    my $nav_param = {chan => $params->{chan}};
    my $need_navbar;
    if ($params->{start} > $params->{size}) {
        $nav_param->{next} = max $params->{start} - $params->{size}, 1;
        $need_navbar++;
    }

    if (@{$params->{data}} >= $params->{size}) {
        $nav_param->{back} = $params->{data}->[-1]->{id};
        $need_navbar++;
    }

    return unless $need_navbar;

    $nav_param->{pos} = $self->{start};
    return $self->render_template('navbar', %$nav_param);
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

sub uri_finder {
    my $self = shift;
    $self->{uri_finder} ||= URI::Find->new(sub { $self->replace_urls(@_) })
}

sub replace_urls {
    my $self = shift;
    my ($url) = @_;

    $self->render_template('url', url => $url);
}


# TODO: replace via CPAN module?
=head2 prepare_highlights

    my $hl = $self->prepare_highlights("1");
    my $hl = $self->prepare_highlights("1,2");
    my $hl = $self->prepare_highlights("1,2..10");

Prepares list of items needs to be highlighted.
Returns sorted arrayref.

=cut

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

1;
