package App::Groonga::Wrapper;
use strict;
use warnings;
use utf8;
use Mouse;
use Mouse::Util::TypeConstraints;
use Twiggy::Server;
use Plack::Builder;
use JSON qw(encode_json);
use Furl;

our $VERSION = '0.01';

my @commands = qw(
	cache_limit check clearlock column_create column_list column_remove define_selector
	defrag delete dump load log_level log_put log_reopen quit select shutdown status
	suggest table_create table_list table_remove view_add
);

subtype
	'PortNumber' =>
	where { my $v = shift; return ( $v > 0 && $v < 0xffff ); },
	as => 'Int';

subtype 'AuthType' => where {/(?:Basic|Digest)/}, as 'Str';

subtype 'StrAll' => where {/^all$/i}, as 'Str';

subtype 'EnableCommands' => as 'HashRef';

coerce 'EnableCommands',
 => from 'StrAll' => via { +{ map { $_ => 1 } @commands } } 
 => from 'ArrayRef' => via { +{ map { $_ => 1 } @{ $_[0] } } };

has 'host' => ( is => 'ro', isa => 'Str',        default => 'localhost', );
has 'port' => ( is => 'ro', isa => 'PortNumber', default => 10041, );

has 'auth_type' => ( is => 'ro', isa => 'AuthType', required => 1, );
has 'realm'  => ( is => 'ro', isa => 'Str', default => 'Groonga Admin', );
has 'secret' => ( is => 'ro', isa => 'Str', default => 'groonga', );

has 'users' => ( is => 'ro', isa => 'HashRef', required => 1, );

has 'enable_commands_global' =>
	( is => 'ro', isa => 'EnableCommands', default => sub { +{} }, );
has 'acceptable_address' =>
	( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] }, );

my %valid_commands = map { $_ => 1 } @commands;

sub run {
	my $self = shift;

	my %acceptable_address = map { $_ => 1 } @{ $self->acceptable_address };
	my $has_acceptable_address = @{ $self->acceptable_address } > 0 ? 1 : 0;

	my $command_pattern = '(' . join( '|', keys %valid_commands ) . ')';
	$command_pattern = '/d/' . $command_pattern . '\??';
	$command_pattern = qr{$command_pattern};

	my $forbidden_res
		= encode_json( [ [ -1, 0, 0, 'Access forbidden' ], [ '', '', '' ] ] );

	my $furl = Furl->new();

	my $auth_type = $self->auth_type || '';
	my $realm     = $self->realm;
	my $users     = $self->users || {};

	for my $user ( keys %$users ) {
		my $enable_commands = $users->{$user}{enable_commands} || [];
		if ( ref $enable_commands && ref $enable_commands eq 'Array' ) {
			$enable_commands = { map { $_ => 1 } @$enable_commands };
		}
		elsif ( !ref($enable_commands) && $enable_commands =~ /^all$/i ) {
			$enable_commands = { %valid_commands };
		}
		else {
			die "Invalid value in 'enable_commands' of user '$user'";
		}
		$users->{$user}{enable_commands} = $enable_commands;
	}

	my $baseuri = 'http://' . $self->host . ':' . $self->port;

	my $app = builder {
		enable 'Auth::Basic',
			realm         => $self->realm,
			authenticator => sub {
			my ( $user, $pw, $env ) = @_;
			$env->{REMOTE_USER} = $user;
			return $users->{$user} && $pw eq $$users->{$user}->{password};
			}
			if $auth_type eq 'Basic';
		enable 'Auth::Digest',
			realm         => $self->realm,
			secret        => $self->secret,
			authenticator => sub {
			my ( $user, $env ) = @_;
			$env->{REMOTE_USER} = $user;
			return $users->{$user} && $users->{$user}{password};
			}
			if $auth_type eq 'Digest';
		sub {

			#command interface
			my $env       = shift;
			my $path_info = $env->{PATH_INFO};
			if ($has_acceptable_address) {
				my $remote_addr = $env->{REMOTE_ADDR};
				if ( !defined $acceptable_address{$remote_addr} ) {
					return [
						200, [ 'Content-Type' => 'application/json' ],
						[$forbidden_res]
					];
				}
			}

			my ($command) = $path_info =~ /$command_pattern/;

			my $user = $env->{REMOTE_USER};
			my $enable_commands;
			if ($user) {
				$enable_commands = $users->{$user}{enable_commands};
			}
			else {
				$enable_commands = $self->enable_commands_global;
			}

			if ($command) {
				if ( !$enable_commands->{$command} ) {
					return [
						200, [ 'Content-Type' => 'application/json' ],
						[$forbidden_res]
					];
				}
			}

			my $uri = $baseuri . $path_info . '?' . $env->{QUERY_STRING};
			my $res = $furl->get($uri);
			return [ $res->code, [ $res->headers->flatten ], [ $res->body ] ];
		};
	};

	my $server = Twiggy::Server->new( port => $self->port, );

	$server->register_service($app);

	AE::cv->recv;
}

no Mouse;
no Mouse::Util::TypeConstraints;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

App::Groonga::Wrapper - Wrapper for Groonga HTTP interface.

=head1 SYNOPSIS

  use App::Groonga::Wrapper;
  App::Groonga::Wrapper->new(
  	
  )->run;
  
  #or
  
  $ groonga_wrapper --config /path/to/config

=head1 DESCRIPTION

App::Groonga::Wrapper is wrapper interface for Groonga.


=head1 METHODS

=over

=item new()

=item run()

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
