use inc::Module::Install;

name     'klog';
all_from 'lib/IRC/Klog.pm';
author   q{Yaroslav Korshak <yko@cpan.org>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

