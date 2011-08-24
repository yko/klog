package Klog::Model::MySQL;
require Class::Load;
require DBIx::Connector;

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    unless ($self->{config}) {
        Carp::croak("No config supplied");
    }
    my $config = $self->{config};

    # FIXME: very unsafe way to build DSN
    my $dsn = 'dbi:mysql';
    if (exists $config->{driver_opts}) {
        $dsn .= '(' . $config->{driver_opts} . ')';
    }
    $dsn .= ':';
    for (qw/database host port/) {
        if (exists $config->{$_}) {
            $dsn .= ";${_}=" . $config->{$_};
        }
    }

    $self->{conn} =
      DBIx::Connector->new($dsn, $config->{user}, $config->{password});

    $self;
}

sub build {
    my $self = shift;
    my ($name) = @_;

    my $class = join '::', __PACKAGE__, $name;
    Class::Load::load_class($class);

    my $model = $class->new(conn => $self->{conn});
}

1;
