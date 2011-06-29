use strict;
use Test::More;
use Test::Fatal qw(lives_ok dies_ok);
use Test::TCP;
use Proc::Guard;

use App::Groonga::Wrapper;
use File::Which qw(which);
use File::Temp qw(tempdir tempfile);
use Path::Class qw(dir);

my $groonga_path = which('groonga');

ok $groonga_path, "Is groonga command exist?";
ok -x $groonga_path, "Is groonga command executable?";

my $server = Test::TCP->new(
	code => sub {
		my $port = shift;
		exec( $groonga_path,
			'-p' => $port,
			'-s',
			'-a'         => 'localhost',
			'--protocol' => 'http'
		);
		die "server execute failed $!";
	}
);

{
	my $dir = dir( tempdir( CLEANUP => 1 ) );
	my ( undef, $filename ) = $dir->tempfile();

	my $groonga;
	lives_ok {
		$groonga = App::Groonga::Wrapper->new(
			port      => $server->port,
			auth_type => 'Digest',
			secret    => 'secret',
			users     => {
				'admin' => {
					password        => 'admin',
					enable_commands => 'All',
				},
			},
		);
	};

	ok defined $groonga;
	ok $groonga->isa('App::Groonga::Wrapper');
	is $groonga->host, 'localhost', 'default host';
	is $groonga->port, $server->port,       'default port number';

	Proc::Guard->new(
		code => sub { $groonga->run() }
	);
	
	#TODO add test by HTTP request
	
}

done_testing();
__DATA__

