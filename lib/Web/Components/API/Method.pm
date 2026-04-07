package Web::Components::API::Method;

use Web::Components::API::Constants
                      qw( FALSE HTTP_METHODS NUL TRUE );
use HTTP::Status      qw( HTTP_OK status_message );
use Unexpected::Types qw( ArrayRef Dict Enum HashRef Int Maybe
                          NonEmptySimpleStr Object Optional Str );
use Type::Utils       qw( class_type );
use Web::Components::API::Argument;
use Web::Components::API::Description;
use Moo;

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Method - Defines the attributes for an API method

=head1 Synopsis

   use Web::Components::API::Method;

=head1 Description

Defines the attributes for an API method

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<access>

A required string. This is presented to the C<context>.C<is_authorised> method
to check of the user making the request has the required permission

=cut

has 'access' => is => 'ro', isa => Str, required => TRUE;

=item C<action>

The name of the subroutine to call. Required

=cut

has 'action' => is => 'ro', isa => Str, required => TRUE;

=item C<additionally>

An optional C<Dict> containing additional documentation displayed for this
method

=cut

has 'additionally' =>
   is  => 'ro',
   isa => Maybe[Dict[
      content     => Str,
      content_raw => Optional[Str],
      title       => Optional[Str],
   ]];

=item C<description>

A text description of this methods purpose

=item C<has_description>

Predicate

=cut

has 'description' =>
   is        => 'lazy',
   isa       => Str,
   init_arg  => undef,
   predicate => TRUE,
   default   => sub {
      my $self = shift;
      my $args = { text => $self->_description };
      my $desc = Web::Components::API::Description->new($args);

      return "${desc}";
   };

has '_description' =>
   is       => 'ro',
   isa      => Str,
   init_arg => 'description',
   default  => 'Undocumented';

=item C<examples>

An array reference of optinal C<Dict> types. Defines the examples used in
the documentation

=cut

has 'examples' =>
   is      => 'ro',
   isa     => ArrayRef[
      Optional[Dict[
         name        => Str,
         body        => Optional[HashRef],
         description => Optional[Str],
         response    => Optional[ArrayRef[HashRef]|HashRef],
         url         => Optional[Str],
      ]]
   ],
   default => sub { [] };

=item C<in_args>

An array reference of L<Web::Components::API::Argument> objects. It defines
what this method call consumes by way of input from the request

=cut

has 'in_args' =>
   is       => 'lazy',
   isa      => ArrayRef[class_type('Web::Components::API::Argument')],
   init_arg => undef,
   default  => sub {
      my $args = shift->_in_args;

      return [ map { Web::Components::API::Argument->new($_) } @{$args} ];
   };

has '_in_args' =>
   is       => 'ro',
   isa      => ArrayRef[HashRef],
   init_arg => 'in_args',
   default  => sub { [] };

=item C<message>

Upon successful completion of the method call, log this optional string

=cut

has 'message' => is => 'ro', isa => Str, default => NUL;

=item C<method>

The HTTP method that this API method responds to. Defaults to C<GET>

=cut

has 'method' => is => 'ro', isa => Enum[HTTP_METHODS], default => 'GET';

=item C<name>

A required string. The name of this method

=cut

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

=item C<out_arg>

An instance of L<Web::Components::API::Argument>. It defines what will be
returned by this method call

=cut

has 'out_arg' =>
   is       => 'lazy',
   isa      => Maybe[class_type('Web::Components::API::Argument')],
   init_arg => undef,
   default  => sub {
      my $arg = shift->_out_arg or return;

      return Web::Components::API::Argument->new($arg);
   };

has '_out_arg' =>
   is       => 'ro',
   isa      => Maybe[HashRef],
   init_arg => 'out_arg';

=item C<route>

This is a required string. It is the partial path of this method in the
request C<URI>

=cut

has 'route' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

=item C<route_display>

Turns the C<route> attribute value into one suitable for displaying in the
documentation

=cut

has 'route_display' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      (my $route = $self->route) =~ s{ \{ (\w+) : [^\}]* \} }{:$1}gmx;

      return $route;
   };

=item C<route_match>

Turns th C<route> attribute value into one suitable for a L<Web::Dispatch>
route

=cut

has 'route_match' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      (my $route = $self->route) =~ s{ \{[^\}]+\} }{\*}gmx;

      return $route;
   };

=item C<success_code>

Defaults to C<HTTP_OK>. The code returned upon successful completion of
this method call

=cut

my $http_status = Int->where( defined status_message($_ // 0) );

has 'success_code' => is => 'ro', isa => $http_status, default => HTTP_OK;

=item C<success_message>

Returns the status message for the C<success_code>

=cut

has 'success_message' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { status_message(shift->success_code) };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILD>

Force the lazy C<in_args> and C<out_arg> to instantiate

=cut

sub BUILD {
   my $self = shift;

   $self->in_args;
   $self->out_arg;
   return;
}

=item C<has_in_args>

Returns true if this methods C<in_args> has an
L<Web::Components::API::Argument> whose C<location> attribute matches the one
provided. Returns false otherwise

=cut

sub has_in_args {
   my ($self, $location) = @_;

   for my $arg (@{$self->in_args}) {
      return TRUE if $arg->location eq $location;
   }

   return FALSE;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<HTTP::Status>

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
