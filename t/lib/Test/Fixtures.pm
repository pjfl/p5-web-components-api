package Test::Fixtures;

use JSON::MaybeXS;
use Moo;

{  package Test::Config;
   use Moo;
   has 'appclass' => is => 'ro';
   has 'prefix'   => is => 'lazy', default => sub { lc shift->appclass };
}

has 'config' =>
   is      => 'ro',
   default => sub { Test::Config->new({ appclass => 'Test' }) };

{  package Test::Log;
   use Moo;
   sub error {}
   sub info {}
}

has 'logger' => is => 'ro', default => sub { Test::Log->new };

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

has 'redis' => is => 'ro', default => sub { Test::RedisClient->new };

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

has 'schema' => is => 'ro', default => sub { DBIx::Class::Schema->new };

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
   sub api_claim {
      my $self = shift;

      return { id => $self->id, role => $self->role->name };
   }
}

my $user = Test::User->new;

has 'user' => is => 'ro', default => sub { $user };

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

has 'factory' => is => 'ro', default => sub { Test::ContextFactory->new };

1;
