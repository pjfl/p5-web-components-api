use t::boilerplate;
use lib 't/lib';

use HTTP::Status qw( HTTP_BAD_REQUEST HTTP_NOT_FOUND HTTP_OK HTTP_UNAUTHORIZED
                     HTTP_UNPROCESSABLE_ENTITY );
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

sub message { my $m = shift->[1]->{message}; chomp $m; return $m }

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

{  package DBIx::Class;
   use Moo;
   has 'active'        => is => 'rw', default => 1;
   has 'artistid'      => is => 'rw', default => 1;
   has 'import_log_id' => is => 'rw';
   has 'name'          => is => 'rw', default => 'A Band';
   has 'upvotes'       => is => 'rw', default => 10;
}
{  package DBIx::Class::ResultSet;
   use Moo;
   sub all {}
   sub create {}
   sub find_by_key {
      my ($self, $key) = @_;
      return unless $key eq 1;
      return DBIx::Class->new;
   }
   sub search {}
}
{  package DBIx::Class::Schema;
   use Moo;
   sub resultset { DBIx::Class::ResultSet->new }
}
my $schema = DBIx::Class::Schema->new;

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
   has '_access_code' => is => 'rw', default => q();
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
   sub is_authorised { my ($self, $code) = @_; $self->_access_code($code) }
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
is $api->routes, 10, 'API Routes - For one entity';

my $entity = $api->get_entity('artist');

is $entity->result_class, 'Artist', 'API Get Entity - Result class';

my $path     = '';
my $query    = {};
my $body     = { username => $user->name, password => 'liarliar' };
my $context  = $factory->new_context('POST', $path, $query, $body);
my $response = $api->authorise($context);

is $response->[0], HTTP_UNAUTHORIZED, 'Authorise - ' . message($response);

$body     = { username => $user->name, password => $user->password };
$context  = $factory->new_context('POST', $path, $query, $body);
$response = $api->authorise($context);

my $token = $response->[1]->{request_token};

is $response->[0], HTTP_OK, 'Authorise - OK';
ok $token, 'Authorise - Request token';
is $redis->get("api_request-${token}"), $user->id, 'Authorise - Stores user ID';
is $redis->_ttl, 180, 'Authorise - Default token lifetime';

$response = $api->access_token($context);

is $response->[0], HTTP_UNAUTHORIZED, 'Access Token - ' . message($response);

$body     = { request_token => $token };
$context  = $factory->new_context('POST', $path, $query, $body);
$response = $api->access_token($context);
$token    = $response->[1]->{access_token};

is $response->[0], HTTP_OK, 'Access Token - OK';
ok $token, 'Access Token - Fetches token';

$context  = $factory->new_context('GET', $path, $query);
$response = $api->dispatch($context, 'v1');

is $response->[0], HTTP_BAD_REQUEST, 'Dispatch - ' . message($response);

$factory->token($token);

$path     = 'rest/dispatch/undeclared';
$context  = $factory->new_context('GET', $path, $query);
$response = $api->dispatch($context, 'v1');

is $response->[0], HTTP_UNPROCESSABLE_ENTITY, 'Dispatch - '.message($response);

$path     = 'rest/dispatch/artist/get';
$context  = $factory->new_context('GET', $path, $query);
$response = $api->dispatch($context, 'v1', 99);

is $response->[0], HTTP_NOT_FOUND, 'Dispatch - ' . message($response);
is $context->_access_code, 'artist/view', 'Dispatch - Access code';

$response = $api->dispatch($context, 'v1', 1);

is $response->[0], HTTP_OK, 'Dispatch - OK';
is $response->[1]->{name}, 'A Band', 'Dispatch - Gets result';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
