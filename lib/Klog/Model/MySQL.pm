package Klog::Model::MySQL;
require Class::Load;

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    unless ($self->{config}) {
        Carp::croak("No config supplied");
    }
    my $config = $self->{config};

    my $dsn = 'dbi:mysql';

    if (exists $config->{driver_opts}) {
        $dsn .= "($config->{driver_opts})";
    }
    $dsn .= ':';

    my @pairs;
    for (qw/database host port/) {
        if (exists $config->{$_}) {
            push @pairs, "${_}=" . $config->{$_};
        }
    }

    $dsn .= join ';', @pairs;

    $self->{dbh} ||= DBI->connect($dsn, $config->{user}, $config->{password});

    $self;
}

sub build {
    my $self = shift;
    my ($name) = @_;

    my $class = join '::', __PACKAGE__, $name;
    Class::Load::load_class($class);

    my $model = $class->new(dbh => $self->{dbh});
}

1;
