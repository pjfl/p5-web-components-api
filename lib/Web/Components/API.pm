package Web::Components::API;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 12 $ =~ /\d+/gmx );

use Web::Components::API::Constants
                          qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_CONFLICT HTTP_FORBIDDEN
                              HTTP_INTERNAL_SERVER_ERROR HTTP_OK
                              HTTP_TOO_MANY_REQUESTS HTTP_UNAUTHORIZED
                              HTTP_UNPROCESSABLE_ENTITY
                              is_error status_message );
use Unexpected::Types     qw( ArrayRef HashRef Int Object Str );
use List::Util            qw( first );
use MIME::Base64          qw( decode_base64url encode_base64url );
use Scalar::Util          qw( blessed );
use Type::Utils           qw( class_type );
use Unexpected::Functions qw( throw Unspecified );
use Web::Components::API::Util
                          qw( create_token digest );
use Web::Components::Util qw( load_components );
use Try::Tiny;
use Moo;

=pod

=encoding utf-8

=head1 Name

Web::Components::API - REST API for Web::Components applications

=head1 Synopsis

   package MyApp::Controller::REST;

   use Web::Components::Util qw( build_routes );
   use Web::Components::API;
   use Web::Simple;

   with 'Web::Components::Role';
   with 'Web::Components::ReverseMap';

   has '+moniker' => default => 'rest';

   has 'api' =>
      is      => 'lazy',
      default => sub {
         my $self = shift;
         my $args = {
            api_config   => $self->api_config,
            config       => $self->config,
            json_parser  => $self->json_parser,
            log          => $self->log,
            redis_client => $self->redis_client,
            schema       => $self->schema,
         };

         return Web::Components::API->new($args);
      };

   has 'api_config' => is => 'lazy', default => sub { {} };

   sub dispatch_request { build_routes
      'POST + /authorise + ?*'    => 'rest/authorise',
      'POST + /access_token + ?*' => 'rest/access_token',
      'POST + /refresh + ?*'      => 'rest/refresh',
      shift->api->routes,
   }

=head1 Description

REST API for L<Web::Components> applications

The example above does not define the attributes used to instantiate the
L<Web::Components::API> object. A model with a C<moniker> of C<rest> is
also required. This should proxy the methods provided by this API object

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<access_token_lifetime>

Length of time in seconds for which the access token is valid. Defaults
to two hours

=cut

has 'access_token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{access_token_lifetime} // 7_200 };

=item C<api_config>

A hash reference of options used to provide defaults for other attributes

=cut

has 'api_config' => is => 'ro', isa => HashRef, default => sub { {} };

=item C<config>

A required configuration object. Passed to the constructor which loads and
instantiates API entities each of which must have L<Web::Components::Role>
applied which requires a C<config> object

=cut

my $config_provider = Object->where('$_->can(q(appclass))');

has 'config' => is => 'ro', isa => $config_provider, required => TRUE;

=item C<dispatch_prefix>

A string which defaults to C<rest/dispatch>. See the C<routes> method

=cut

has 'dispatch_prefix' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->api_config->{dispatch_prefix} // 'rest/dispatch' };

=item C<entity_list>

A sorted list of entity names

=cut

has 'entity_list' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { [ sort keys %{shift->entities} ] };

=item C<entities>

An array of objects that inherit from L<Web::Components::API::Base>. These
are loaded and instantiated from the classes found in the C<API> directory
of the C<config>.C<appclass> namespace
=cut

has 'entities' =>
   is      => 'lazy',
   isa     => HashRef[class_type('Web::Components::API::Base')],
   default => sub {
      my $self = shift;
      my $args = {
         application   => $self,
         max_page_size => $self->max_page_size,
         schema        => $self->schema,
      };

      return load_components 'API', $args;
   };

=item C<json_parser>

A required JSON parsing object. Should provide C<decode> and C<encode> methods

=cut

my $json_parser = Object->where('$_->can(q(decode)) && $_->can(q(encode))');

has 'json_parser' => is => 'ro', isa => $json_parser, required => TRUE;

=item C<log>

A required logging object. Should provide C<error> and C<info> methods

=cut

my $logger = Object->where('$_->can(q(error)) && $_->can(q(info))');

has 'log' => is => 'ro', isa => $logger, required => TRUE;

=item C<max_page_size>

Maximum number of objects to return in a single API call. Defaults to two
hundred

=cut

has 'max_page_size' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{max_page_size} // 200 };

=item C<max_req_per_min>

Maximum number of requests per minute. Used to throttle clients. Defaults
to five

=cut

has 'max_req_per_min' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{max_req_per_min} // 5 };

=item C<redis_client>

A required L<Redis> client object. Should provide C<del>, C<get> and
C<set_with_ttl> methods

=cut

my $redis_client = Object->where('$_->can(q(set_with_ttl))');

has 'redis_client' => is => 'ro', isa => $redis_client, required => TRUE;

=item C<refresh_token_lifetime>

Length of time in seconds for which the access token will be able to
successfully call the refresh endpoint. Defaults to twelve hours. After this
re-authorisation will needed. If set to zero an access token will continue to
refresh indefinitely

=cut

has 'refresh_token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{refresh_token_lifetime} // 43_200 };

=item C<request_token_lifetime>

Length of time in seconds that the request token will be valid. Defaults
to three minutes

=cut

has 'request_token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{request_token_lifetime} // 180 };

=item C<route_match_prefix>

A string which defaults to C</*>. See the C<routes> method

=cut

has 'route_match_prefix' =>
   is      => 'ro',
   isa     => Str,
   default => sub { shift->api_config->{route_match_prefix} // '/*' };

=item C<route_prefix>

A string used in the documentation output. Defaults to C<rest/v1> where
the C<1> is the current API version number

=cut

has 'route_prefix' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { 'rest/v' . shift->versions->[-1] };

=item C<schema>

A required instance of L<DBIx::Class::Schema>

=cut

has 'schema' => is => 'ro', required => TRUE;

=item C<secret>

A string used to create and verify access tokens

=cut

has 'secret' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->api_config->{secret} // NUL };

=item C<versions>

An array reference of version numbers currently supported. Defaults to
C<[1]>

=cut

has 'versions' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { shift->api_config->{versions} // [1] };

# Private attributes
has '_request_history' => is => 'ro', isa => HashRef, default => sub { {} };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<authorise>

   $response = $self->authorise($context);

Obtain a C<request_token>. The response contains an HTTP status code and a hash
reference which forms the body containing the token. Requires C<username> and
C<password> on C<context>.C<request>.C<body_parameters>. Requires C<find_user>
and C<authenticate> on C<context>

=cut

sub authorise {
   my ($self, $context) = @_;

   my $req     = $context->request;
   my $options = {
      address  => $req->remote_address,
      username => $req->body_parameters->{username},
      password => $req->body_parameters->{password},
   };
   my $response;

   try {
      $options->{user} = $context->find_user($options);
      $context->authenticate($options);

      my $token    = create_token;
      my $key      = "api_request-${token}";
      my $userid   = $options->{user}->id;
      my $lifetime = $self->request_token_lifetime;

      $self->redis_client->set_with_ttl($key, $userid, $lifetime);
      $response = [HTTP_OK, { request_token => $token }];
   }
   catch { $response = [HTTP_UNAUTHORIZED, { message => "${_}" }] };

   return $response;
}

=item C<access_token>

   $response = $self->access_token($context);

Exchanges a C<request_token> for a JWT C<access_token>

The response contains an HTTP status code and a hash reference which forms the
body containing the token. Obtains C<request_token> from
C<context>.C<request>.C<body_parameters>

The user object returned by C<context>.C<find_user> is expected to have an
C<api_claim> method which returns the claim hash reference. The keys/values in
the claim hash reference are applied to C<context>.C<request>.C<session> if the
session object has attributes of the same name. This will enable
C<context>.C<is_authorised> to obtain user identity information when it is
called by the C<dispatch> method

=cut

sub access_token {
   my ($self, $context) = @_;

   my $token = $context->request->body_parameters->{request_token};

   return [HTTP_UNAUTHORIZED, { message => 'No request token' }] unless $token;

   my $userid = $self->redis_client->get("api_request-${token}");

   return [HTTP_UNAUTHORIZED, { message => 'No cached token' }] unless $userid;

   $self->redis_client->del("api_request-${token}");

   my $user = $context->find_user({ username => $userid });
   my $body = { message => "User '${userid}' not found" };

   return [HTTP_UNAUTHORIZED, $body] unless $user;

   $token = $self->_create_access_token($user);
   $body  = { message => "User '${userid}' no api group" };

   return [HTTP_UNAUTHORIZED, $body] unless $token;

   return [HTTP_OK, { access_token => $token }];
}

=item C<dispatch>

   $response = $self->dispatch($context, @args);

Obtains C<moniker/action> from C<context>.C<action>. Uses the C<moniker> to get
the API entity and then calls C<action> on that object. Requires a valid
C<access_token> on C<context>.C<request>.C<headers>.C<Authorization>. Requires
C<is_authorised> on C<context>. The C<args> are the positional parameters from
the request. The first argument should be the version from the request path
(defaults to v1)

=cut

sub dispatch {
   my ($self, $context, @args) = @_;

   my $version  = shift @args;
   my $response = $self->_is_throttled($context);

   return $response if is_error($response->[0]);

   $response = $self->_is_authorised($context);

   return $response if is_error($response->[0]);

   $self->_update_session($context, $response->[1]);

   try {
      my ($moniker, $action) = $self->_get_dispatch_args($context);
      my $entity = $self->get_entity($moniker);
      my $method = $self->_versioned_method($entity, $action, $version);

      $response = $entity->$method($context, @args);

      my $message = $entity->get_message($action, $response->[2]);

      $self->log->info($message, $context) if $message;
   }
   catch { $response = $self->_handle_errors($context, $_) };

   return $response;
}

=item C<get_entity>

   $entity_object = $self->get_entity($moniker);

All API entities must do L<Web::Components::Role> which gives them a unique
attribute C<moniker>. Returns the entity object for the given C<moniker>

=cut

sub get_entity {
   my ($self, $moniker) = @_;

   $moniker //= $self->entity_list->[0] // NUL;

   throw Unspecified, ['moniker'] unless $moniker;

   my $entity = $self->entities->{$moniker};

   throw 'Moniker [_1] unknown', [$moniker] unless $entity;

   return $entity;
}

=item C<refresh>

   $response = $self->refresh($context);

Obtains a fresh C<access_token>

The response contains an HTTP status code and a hash reference which forms the
body containing the token. Requires a valid C<access_token> from
C<context>.C<request>.C<headers>.C<Authorization>

An C<access_token> will only refresh for the C<refresh_token_lifetime>, after
that re-authorisation will be required

=cut

sub refresh {
   my ($self, $context) = @_;

   my $response = $self->_is_authorised($context);

   return $response if is_error($response->[0]);

   my $elapsed  = time - $response->[1]->{_created};
   my $lifetime = $self->refresh_token_lifetime;
   my $body     = { message => 'Token too old' };

   return [HTTP_UNAUTHORIZED, $body] if $lifetime && $elapsed > $lifetime;

   $body = { access_token => $self->_encode_access_token($response->[1]) };

   return [HTTP_OK, $body];
}

=item C<routes>

   @routes = $self->routes;

This should be called from within a L<Web::Simple> C<dispatch_request> method.
Returns a list of pairs of strings. Each pair is a L<Web::Dispatch> route and
C<moniker/method_chain> used by L<Web::Components> to implement chained
dispatch

=cut

sub routes {
   my $self   = shift;
   my $prefix = $self->route_match_prefix;
   my @routes = ();

   for my $moniker (keys %{$self->entities}) {
      my $entity = $self->entities->{$moniker};

      for my $method (@{$entity->method_list}) {
         my $match  = $method->route_match;
         my $route  = $method->method . " + ${prefix}${match} + ?*";
         my $action = $method->action;

         push @routes, $route, $self->_get_dispatch_method($moniker, $action);
      }
   }

   return @routes;
}

# Private methods
sub _create_access_token {
   my ($self, $user) = @_;

   my $claim = $user->api_claim or return;

   return $self->_encode_access_token($claim);
}

sub _decode_access_token {
   my ($self, $token) = @_;

   my ($salt, $payload, $verify) = split m{ \. }mx, $token;
   my $calculated = $self->_jwt_hash("${salt}${payload}");

   return {} unless $verify eq $calculated;

   return $self->json_parser->decode(decode_base64url($payload));
}

sub _encode_access_token {
   my ($self, $claim) = @_;

   $claim->{_refreshed} = time;
   $claim->{_created} //= $claim->{_refreshed};

   my $salt    = encode_base64url(pack('H*', create_token));
   my $payload = encode_base64url($self->json_parser->encode($claim));
   my $verify  = $self->_jwt_hash("${salt}${payload}");

   return "${salt}.${payload}.${verify}";
}

sub _get_dispatch_args {
   my ($self, $context) = @_;

   my $method = $context->action // NUL;
   my (undef, undef, $moniker, $action) = split m{ / }mx, $method;

   return ($moniker, $action);
}

sub _get_dispatch_method {
   my ($self, $moniker, $action) = @_;

   return $self->dispatch_prefix . "/${moniker}/${action}";
}

sub _handle_errors {
   my ($self, $context, $error) = @_;

   my $message = "${error}"; chomp $message;
   my $code    = HTTP_INTERNAL_SERVER_ERROR;

   if (blessed $error && $error->can('rv')) {
      $code    = HTTP_UNPROCESSABLE_ENTITY;
      $code    = $error->rv if status_message($error->rv);
      $message = $error->original;
   }
   else {
      if ($message =~ m{ duplicate \s key \s value }mx) {
         $message = 'Duplicate key';
         $code    = HTTP_CONFLICT;
      }
   }

   $self->log->error($message, $context) if $code == HTTP_INTERNAL_SERVER_ERROR;

   return [$code, { message => $message }];
}

sub _is_authorised {
   my ($self, $context) = @_;

   my $header = $context->request->header('Authorization');

   return [HTTP_BAD_REQUEST, { message => 'No authorization header'}]
      unless $header;

   my ($type, $token) = split m{ [ ]+ }mx, $header;

   return [HTTP_BAD_REQUEST, { message => 'No access token' }] unless $token;

   my $claim = $self->_decode_access_token($token);

   return [HTTP_UNAUTHORIZED, { message => 'Token verification failed'}]
      unless $claim->{_created};

   my $elapsed = time - $claim->{_refreshed};

   return [HTTP_UNAUTHORIZED, { message => 'Token too old' }]
      if $elapsed > $self->access_token_lifetime;

   return [HTTP_OK, $claim];
}

sub _is_throttled {
   my ($self, $context) = @_;

   my $default = { stamp => 0, count => 0 };
   my $address = $context->request->remote_address;
   my $record  = $self->_request_history->{$address} // $default;
   my $max_rpm = $self->max_req_per_min;
   my $body    = { message => "Maximum ${max_rpm} requests per minute" };
   my $now     = time;

   $record->{count} += 1;

   $record = { stamp => $now, count => 1 } if $now - $record->{stamp} > 60;

   $self->_request_history->{$address} = $record;

   return [HTTP_TOO_MANY_REQUESTS, $body] if $record->{count} > $max_rpm;

   return [HTTP_OK];
}

sub _jwt_hash {
   my ($self, $payload) = @_;

   my $secret = $self->secret;

   return substr digest("${payload}${secret}")->hexdigest, 0, 32;
}

sub _update_session {
   my ($self, $context, $claim) = @_;

   $claim->{address}       = $context->request->remote_address;
   $claim->{authenticated} = TRUE;

   my $session = $context->session;

   for my $key (grep { $_ !~ m{ \A _ }mx } keys %{$claim}) {
      $session->$key($claim->{$key}) if $session->can($key);
   }

   return;
}

sub _versioned_method {
   my ($self, $entity, $action, $version) = @_;

   throw Unspecified, ['action'] unless $action;

   (my $wanted = $version) =~ s{ \A v }{}mx;
   my $current = $self->versions->[-1];

   return $action if $wanted == $current;

   for my $candidate (@{$self->versions}) {
      next if $candidate < $wanted;

      my $method = "${action}_v{$candidate}";

      return $method if $entity->can($method);
   }

   return $action;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Web::Components>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Web-Components-API.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
