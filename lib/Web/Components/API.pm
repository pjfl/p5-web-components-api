package Web::Components::API;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Web::Components::API::Constants
                           qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CONFLICT HTTP_FORBIDDEN
                               HTTP_INTERNAL_SERVER_ERROR HTTP_OK
                               HTTP_TOO_MANY_REQUESTS HTTP_UNAUTHORIZED
                               HTTP_UNPROCESSABLE_ENTITY
                               is_error status_message );
use Unexpected::Types      qw( ArrayRef HashRef Int Str );
use Class::Usul::Cmd::Util qw( includes );
use List::Util             qw( first );
use MIME::Base64           qw( decode_base64url encode_base64url );
use Scalar::Util           qw( blessed );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw );
use Web::Components::API::Util
                           qw( create_token digest );
use Web::Components::Util  qw( load_components );
use Try::Tiny;
use Moo;

# Context requires: authenticate find_user is_authorised
# request session stash

=pod

=encoding utf-8

=head1 Name

Web::Components::API - REST API for Web::Components applications

=head1 Synopsis

   use Web::Components::API;

=head1 Description

REST API for Web::Components applications

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item access_token_lifetime

=cut

has 'access_token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{access_token_lifetime} // 7_200 };

=item api_config

=cut

has 'api_config' => is => 'ro', isa => HashRef, default => sub { {} };

=item config

=cut

has 'config' => is => 'ro', required => TRUE;

=item dispatch_prefix

=cut

has 'dispatch_prefix' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->api_config->{dispatch_prefix} // 'rest/dispatch' };

=item entity_list

=cut

has 'entity_list' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { [ sort keys %{shift->entities} ] };

=item entities

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

=item json_parser

=cut

has 'json_parser' => is => 'ro', required => TRUE;

=item log

=cut

has 'log' => is => 'ro', required => TRUE;

=item max_page_size

=cut

has 'max_page_size' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{max_page_size} // 250 };

=item max_req_per_min

=cut

has 'max_req_per_min' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{max_req_per_min} // 5 };

=item redis_client

=cut

has 'redis_client' => is => 'ro', required => TRUE;

=item request_history

=cut

has 'request_history' => is => 'ro', isa => HashRef, default => sub { {} };

=item request_token_lifetime

=cut

has 'request_token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->api_config->{request_token_lifetime} // 180 };

=item route_match_prefix

=cut

has 'route_match_prefix' => is => 'ro', isa => Str, default => '/*';

=item route_prefix

=cut

has 'route_prefix' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { 'rest/v' . shift->versions->[-1] };

=item schema

=cut

has 'schema' => is => 'ro', required => TRUE;

=item secret

=cut

has 'secret' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->api_config->{secret} // NUL };

=item versions

=cut

has 'versions' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { shift->api_config->{versions} // [1] };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item access_token

=cut

sub access_token {
   my ($self, $context) = @_;

   my $token = $context->request->body_parameters->{request_token};

   return [HTTP_UNAUTHORIZED, { message => 'No request token' }] unless $token;

   my $userid = $self->redis_client->get("api_request-${token}");

   return [HTTP_UNAUTHORIZED, { message => 'No cached token' }] unless $userid;

   $self->redis_client->del("api_request-${token}");

   my $user = $context->find_user({ username => $userid });

   return [HTTP_UNAUTHORIZED, { message => "User ${userid} not found" }]
      unless $user;

   return [HTTP_OK, { access_token => $self->_create_access_token($user) }];
}

=item authorise

=cut

sub authorise {
   my ($self, $context) = @_;

   my $req     = $context->request;
   my $options = {
      address  => $req->remote_address,
      username => $req->body_parameters->{username},
      password => $req->body_parameters->{password},
   };
   my $result;

   try {
      $options->{user} = $context->find_user($options);
      $context->authenticate($options);

      my $token    = create_token;
      my $userid   = $options->{user}->id;
      my $lifetime = $self->request_token_lifetime;
      my $key      = "api_request-${token}";

      $self->redis_client->set_with_ttl($key, $userid, $lifetime);
      $result = [HTTP_OK, { request_token => $token }];
   }
   catch { $result = [HTTP_UNAUTHORIZED, { message => "${_}" }] };

   return $result;
}

=item dispatch

=cut

sub dispatch {
   my ($self, $context, @args) = @_;

   my $version = shift @args;
   my $result  = $self->_is_throttled($context);

   return $result if is_error($result->[0]);

   $result = $self->_is_authorised($context);

   return $result if is_error($result->[0]);

   my $claim = $result->[1];

   $self->_update_session($context, $claim);

   try {
      my $chain  = $context->stash('method_chain');
      my (undef, $moniker, $action) = split m{ / }mx, $chain;
      my $entity = $self->entities->{$moniker};
      my $method = $self->_versioned_method($entity, $action, $version);

      $result = $entity->$method($context, @args);

      my $message = $entity->get_message($action, $result->[2]);

      $self->log->info($message, $context) if $message;
   }
   catch { $result = $self->_handle_errors($context, $_) };

   return $result;
}

=item get_entity

=cut

sub get_entity {
   my ($self, $moniker) = @_;

   $moniker //= $self->entity_list->[0];

   return $self->entities->{$moniker};
}

=item refresh

=cut

sub refresh {
   my ($self, $context) = @_;

   my $result = $self->_is_authorised($context);

   return $result if is_error($result->[0]);

   my $claim = $result->[1];

   return [HTTP_OK, { access_token => $self->_encode_access_token($claim) }];
}

=item routes

=cut

sub routes {
   my $self   = shift;
   my $dpref  = $self->dispatch_prefix;
   my $mpref  = $self->route_match_prefix;
   my @routes = ();

   for my $moniker (keys %{$self->entities}) {
      my $entity = $self->entities->{$moniker};

      for my $method (@{$entity->method_list}) {
         my $match  = $method->route_match;
         my $route  = $method->method . " + ${mpref}${match} + ?*";
         my $action = $method->action;

         push @routes, $route, "${dpref}/${moniker}/${action}";
      }
   }

   return @routes;
}

# Private methods
sub _create_access_token {
   my ($self, $user) = @_;

   my $role = $user->role->name;

   return $self->_encode_access_token({ id => $user->id, role => $role });
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

   $claim->{time} = time;

   my $salt    = encode_base64url(pack('H*', create_token));
   my $payload = encode_base64url($self->json_parser->encode($claim));
   my $verify  = $self->_jwt_hash("${salt}${payload}");

   return "${salt}.${payload}.${verify}";
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
      unless $claim->{id};

   my $elapsed = time - $claim->{time};

   return [HTTP_UNAUTHORIZED, { message => 'Token too old' }]
      unless $elapsed < $self->access_token_lifetime;

   return [HTTP_OK, $claim];
}

sub _is_throttled {
   my ($self, $context) = @_;

   my $default = { stamp => 0, count => 0 };
   my $address = $context->request->remote_address;
   my $record  = $self->request_history->{$address} // $default;
   my $max_rpm = $self->max_req_per_min;
   my $message = "Maximum ${max_rpm} requests per minute";
   my $now     = time;

   $record->{count} += 1;

   $record = { stamp => $now, count => 1 } if $now - $record->{stamp} > 60;

   $self->request_history->{$address} = $record;

   return [HTTP_TOO_MANY_REQUESTS, { message => $message } ]
      if $record->{count} > $max_rpm;

   return [HTTP_OK];
}

sub _jwt_hash {
   my ($self, $payload) = @_;

   my $secret = $self->secret;

   return substr digest("${payload}${secret}")->hexdigest, 0, 32;
}

sub _update_session {
   my ($self, $context, $claim) = @_;

   my $session = $context->session;

   $session->address($context->request->remote_address);
   $session->authenticated(TRUE);
   $session->id($claim->{id});
   $session->role($claim->{role});
   return;
}

sub _versioned_method {
   my ($self, $entity, $action, $version) = @_;

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

=item L<Wev::Components>

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
