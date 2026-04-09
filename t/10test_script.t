use t::boilerplate;
use lib 't/lib';

use HTTP::Status qw( HTTP_BAD_REQUEST HTTP_NOT_FOUND HTTP_OK HTTP_UNAUTHORIZED
                     HTTP_UNPROCESSABLE_ENTITY );
use Scalar::Util qw( blessed );
use IO::String;
use JSON::MaybeXS;
use Web::ComposableRequest;
use Test::Fixtures;
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

sub message { my $m = shift->[1]->{message}; chomp $m; return $m }

my $fixtures    = Test::Fixtures->new;
my $json_parser = JSON::MaybeXS->new;
my $args        = {
   config       => $fixtures->config,
   json_parser  => $json_parser,
   log          => $fixtures->logger,
   redis_client => $fixtures->redis,
   schema       => $fixtures->schema,
};
my $api = Web::Components::API->new($args);

is blessed $api, 'Web::Components::API', 'API Constructs';
is $api->routes, 10, 'API Routes - For one entity';

my $entity = $api->get_entity('artist');

is $entity->result_class, 'Artist', 'API Get Entity - Result class';

my $path     = '';
my $query    = {};
my $user     = $fixtures->user;
my $body     = { username => $user->name, password => 'liarliar' };
my $context  = $fixtures->factory->new_context('POST', $path, $query, $body);
my $response = $api->authorise($context);

is $response->[0], HTTP_UNAUTHORIZED, 'Authorise - ' . message($response);

$body     = { username => $user->name, password => $user->password };
$context  = $fixtures->factory->new_context('POST', $path, $query, $body);
$response = $api->authorise($context);

my $token = $response->[1]->{request_token};

is $response->[0], HTTP_OK, 'Authorise - OK';
ok $token, 'Authorise - Request token';
is $fixtures->redis->get("api_request-${token}"), $user->id,
   'Authorise - Stores user ID';
is $fixtures->redis->_ttl, 180, 'Authorise - Default token lifetime';

$response = $api->access_token($context);

is $response->[0], HTTP_UNAUTHORIZED, 'Access Token - ' . message($response);

$body     = { request_token => $token };
$context  = $fixtures->factory->new_context('POST', $path, $query, $body);
$response = $api->access_token($context);
$token    = $response->[1]->{access_token};

is $response->[0], HTTP_OK, 'Access Token - OK';
ok $token, 'Access Token - Fetches token';

$context  = $fixtures->factory->new_context('GET', $path, $query);
$response = $api->dispatch($context, 'v1');

is $response->[0], HTTP_BAD_REQUEST, 'Dispatch - ' . message($response);

$fixtures->factory->token($token);

$path     = 'rest/dispatch/undeclared';
$context  = $fixtures->factory->new_context('GET', $path, $query);
$response = $api->dispatch($context, 'v1');

is $response->[0], HTTP_UNPROCESSABLE_ENTITY, 'Dispatch - '.message($response);

$path     = 'rest/dispatch/artist/get';
$context  = $fixtures->factory->new_context('GET', $path, $query);
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
