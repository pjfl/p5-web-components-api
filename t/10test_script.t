use t::boilerplate;

use Scalar::Util qw( blessed );
use Class::Null;
use JSON::MaybeXS;
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

{  package Test::Config;
   use Moo;
   has 'appclass' => is => 'ro';
}
{  package Test::Log;
   use Moo;
   sub error {}
   sub info {}
}
{  package Test::RedisClient;
   use Moo;
   sub del {}
   sub get {}
   sub set_with_ttl {}
}

my $args = {
   config       => Test::Config->new({ appclass => 'Test' }),
   json_parser  => JSON::MaybeXS->new,
   log          => Test::Log->new,
   redis_client => Test::RedisClient->new,
   schema       => Class::Null->new,
};
my $api = Web::Components::API->new($args);

is blessed $api, 'Web::Components::API', 'API constructs';
is $api->routes, 0, 'API routes - empty';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
