use Test::More tests => 6;

BEGIN {
    use_ok( 'Klog::Web::Controller' );
}

my $c = new_ok 'Klog::Web::Controller::Foo';

$c->{models_factory} = sub {
    my $name = shift;
    return 'Model - ' . $name;
};

is $c->model, 'Model - Foo';
is $c->{models}{Foo}, 'Model - Foo';

is $c->model('Bar'), 'Model - Bar';
is $c->{models}{Bar}, 'Model - Bar';

package Klog::Web::Controller::Foo;

use base 'Klog::Web::Controller';

1;
