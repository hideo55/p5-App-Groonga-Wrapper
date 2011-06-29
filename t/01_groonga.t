use strict;
use Test::More;
use Test::Fatal qw(lives_ok dies_ok);
use Proc::Guard;

use App::Groonga::Wrapper;
use File::Which qw(which);
use File::Temp qw(tempdir tempfile);
use Path::Class qw(dir);

my $groonga_path = which('groonga');

ok $groonga_path, "Is groonga command exist?";
ok -x $groonga_path, "Is groonga command executable?";

{
	my $dir = dir(tempdir( CLEANUP => 1 ));
	my (undef, $filename) = $dir->tempfile();
	
	my $groonga;
	lives_ok {
		$groonga = App::Groonga::Wrapper->new(
			auth_type => 'Digest',
			secret => 'secret',
			users => {
				'admin' => {
					password => 'admin',
					enable_commands => 'All',
				},
			},
		)
	};
	
	ok defined $groonga;
	ok $groonga->isa('App::Groonga::Wrapper');
	is $groonga->host, 'localhost', 'default host';
	is $groonga->port, 10041, 'default port number';
	
	#$groonga->run();
}


done_testing();
__DATA__

