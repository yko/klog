use inc::Module::Install;

name     'klog';
all_from 'lib/POE/Klog.pm';
author   q{Yaroslav Korshak <yko@cpan.org>};
license  'perl';

requires 'File::Spec';
requires 'FindBin';
requires 'Encode';
requires 'List::Util';

requires 'POE';
requires 'POE::Component::IRC';
requires 'DBI';
requires 'DBD::mysql';
requires 'Routes::Tiny';
requires 'Text::Caml';
requires 'Plack';

build_requires 'Test::More';

auto_install;

WriteAll;
