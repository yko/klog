use inc::Module::Install;

name     'klog';
all_from 'lib/Klog/Web.pm';
author   q{Yaroslav Korshak <yko@cpan.org>};
license  'perl';

requires 'File::Spec';
requires 'FindBin';
requires 'Encode';
requires 'List::Util';

requires 'POE';
requires 'POE::Component::IRC';
requires 'DBI';
requires 'DBIx::Connector';
requires 'Class::Load';
requires 'String::CamelCase';
requires 'DBD::mysql';
requires 'Routes::Tiny';
requires 'Text::Caml';
requires 'Plack';
requires 'URI::Find';
requires 'Config::INI';

build_requires 'Test::More';

auto_install;

WriteAll;
