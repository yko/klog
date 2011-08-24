package Klog::Config;

require Config::INI::Reader;
require File::Spec;
require FindBin;

our $DEFAULT = 'klog.ini';

sub new { my $class = shift; bless {@_}, $class }

sub load {
    my $self = ref $_[0] ? shift : shift->new;

    my $file = shift;
    $file ||= $self->{default} || $DEFAULT;

    if (!File::Spec->file_name_is_absolute($file)) {
        $file = File::Spec->catfile($self->home, $file);
    }

    Config::INI::Reader->read_file($file);
}

sub home {
    my $self = shift;
    $self->{home} ||= File::Spec->catfile($FindBin::Bin, '..');
}

1;
