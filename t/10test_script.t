use t::boilerplate;

use HTTP::Status qw( HTTP_OK HTTP_UNAUTHORIZED HTTP_UNPROCESSABLE_ENTITY );
use Scalar::Util qw( blessed );
use IO::String;
use JSON::MaybeXS;
use Web::ComposableRequest;
use Test::More;

use_ok 'Web::Components::API::Constants';
use_ok 'Web::Components::API::Util';
use_ok 'Web::Components::API::Meta';
use_ok 'Web::Components::API::Moo';
use_ok 'Web::Components::API::Argument';
use_ok 'Web::Components::API::Description';
use_ok 'Web::Components::API::Column';
use_ok 'Web::Components::API::Method';
use_ok 'Web::Components::API::Base';
use_ok 'Web::Components::API';

my $ttl;

sub message { shift->[1]->{message} }
{  package Test::Config;
   use Moo;
   has 'appclass' => is => 'ro';
   has 'prefix'   => is => 'lazy', default => sub { lc shift->appclass };
}
my $config = Test::Config->new({ appclass => 'Test' });
{  package Test::Log;
   use Moo;
   sub error {}
   sub info {}
}
my $logger = Test::Log->new;
{  package Test::RedisClient;
   use Moo;
   has '_store' => is => 'ro', default => sub { {} };
   has '_ttl'   => is => 'rw';
   sub del {
      my ($self, $key) = @_;
      return delete $self->_store->{$key};
   }
   sub get {
      my ($self, $key) = @_;
      return $self->_store->{$key};
   }
   sub set_with_ttl {
      my ($self, $key, $value, $ttl) = @_;
      $self->_ttl($ttl);
      return $self->_store->{$key} = $value;
   }
}
my $redis = Test::RedisClient->new;
{  package Test::ResultSet;
   sub new { bless {}, 'DBIx::Class::ResultSet' }
   sub all {}
   sub create {}
   sub find_by_key {}
   sub search {}
}
{  package Test::Schema;
   sub new { bless {}, 'DBIx::Class::Schema' }
   sub resultset { Test::ResultSet->new }
}
my $schema = Test::Schema->new;
{  package Test::Role;
   use Moo;
   has 'name' => is => 'ro', default => 'edit';
}
{  package Test::User;
   use Moo;
   has 'id'       => is => 'ro', default => 2;
   has 'name'     => is => 'ro', default => 'TestUser';
   has 'password' => is => 'ro', default => 'secret';
   has 'role'     => is => 'ro', default => sub { Test::Role->new };
}
my $user = Test::User->new;
{  package Test::Context;
   use Unexpected::Functions qw( throw );
   use Moo;
   extends 'Web::Components::Context';
   sub authenticate {
      my ($self, $options) = @_;
      return 1 if $user->password eq $options->{password};
      throw 'Bad password';
   }
   sub find_user {
      my ($self, $options) = @_;
      my $username = $options->{username};
      return $user if $username =~ m{ \d }mx && $user->id eq $username;
      return $user->name eq $username ? $user : undef;
   }
   sub is_authorised { warn $_[1] }
}
my $json_parser = JSON::MaybeXS->new;
{  package Test::ContextFactory;
   use Moo;
   has 'request' => is => 'rw';
   has 'token'   => is => 'rw', default => q();
   sub new_context {
      my ($self, $method, $path, $query, $body) = @_;

      my $input = $body ? $json_parser->encode($body) : q();
      my $env   = {
         CONTENT_LENGTH       => length $input,
         CONTENT_TYPE         => 'application/json',
         HTTP_ACCEPT_LANGUAGE => 'en-gb,en;q=0.7,de;q=0.3',
         HTTP_AUTHORIZATION   => 'Bearer ' . $self->token,
         HTTP_HOST            => 'localhost:5000',
         HTTP_REFERER         => 'asif',
         PATH_INFO            => '/rest',
         QUERY_STRING         => '',
         REMOTE_ADDR          => '127.0.0.1',
         REMOTE_HOST          => 'notlikely',
         REQUEST_METHOD       => $method,
         SERVER_PROTOCOL      => 'HTTP/1.1',
        'psgi.input'         => IO::String->new($input),
        'psgix.logger'       => sub { warn shift->{message}."\n" },
      };
      my $config  = { request_roles => [qw(L10N Session Headers JSON Compat)] };
      my $factory = Web::ComposableRequest->new(config => $config);
      $self->request($factory->new_from_simple_request({}, $path, $query,$env));
      return Test::Context->new(action => $path, request => $self->request);
   }
}
my $factory = Test::ContextFactory->new;

my $args = {
   config       => $config,
   json_parser  => $json_parser,
   log          => $logger,
   redis_client => $redis,
   schema       => $schema,
};
my $api  = Web::Components::API->new($args);

is blessed $api, 'Web::Components::API', 'API Constructs';
is $api->routes, 0, 'API Routes - Empty';

my $path    = '';
my $query   = {};
my $body    = { username => $user->name, password => $user->password };
my $context = $factory->new_context('POST', $path, $query, $body);
my $result  = $api->authorise($context);
my $token   = $result->[1]->{request_token};

is $result->[0], HTTP_OK, 'Authorise - OK';
ok $token, 'Authorise - Request token';
is $redis->get("api_request-${token}"), $user->id, 'Authorise - Stores user ID';
is $redis->_ttl, 180, 'Authorise - Default token lifetime';

$result = $api->access_token($context);

is $result->[0], HTTP_UNAUTHORIZED, 'Access Token - ' . message($result);

$body    = { request_token => $token };
$context = $factory->new_context('POST', $path, $query, $body);
$result  = $api->access_token($context);
$token   = $result->[1]->{access_token};

is $result->[0], HTTP_OK, 'Access Token - OK';
ok $token, 'Access Token - Fetches token';

$factory->token($token);

$path    = 'rest/dispatch/artist';
$context = $factory->new_context('GET', $path, $query);
$result  = $api->dispatch($context);

is $result->[0], HTTP_UNPROCESSABLE_ENTITY, 'Dispatch - ' . message($result);

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
