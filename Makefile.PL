use inc::Module::Install;
name 'App-Groonga-Wrapper';
all_from 'lib/App/Groonga/Wrapper.pm';

requires 'Twiggy';
requires 'Plack';
requires 'Furl';
requires 'Mouse';
requires 'JSON';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
test_requires 'Test::Fatal';
test_requires 'Test::TCP';
test_requires 'File::Which';
test_requires 'Proc::Guard';

auto_set_repository;
auto_include;
WriteAll;
