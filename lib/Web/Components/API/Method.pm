package Web::Components::API::Method;

use Web::Components::API::Constants
                      qw( FALSE NUL TRUE );
use HTTP::Status      qw( HTTP_OK status_message );
use Unexpected::Types qw( ArrayRef Dict Enum HashRef Int Maybe
                          NonEmptySimpleStr Object Optional Str );
use Type::Utils       qw( class_type );
use Web::Components::API::Argument;
use Web::Components::API::Description;
use Moo;

my $http_methods = Enum[qw( GET PUT POST DELETE )];
my $http_status  = Int->where( defined status_message($_) );

has 'access' => is => 'ro', isa => Str, required => TRUE;

has 'action' => is => 'ro', isa => Str, required => TRUE;

has 'additionally' =>
   is  => 'ro',
   isa => Maybe[Dict[
      content     => Str,
      content_raw => Optional[Str],
      title       => Optional[Str],
   ]];

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

has 'message' => is => 'ro', isa => Str, default => NUL;

has 'method' => is => 'ro', isa => $http_methods, default => 'GET';

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

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

has 'route'  => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'success_code' => is => 'ro', isa => $http_status, default => HTTP_OK;

has 'success_message' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { status_message(shift->success_code) };

sub BUILD {
   my $self = shift;

   $self->in_args;
   $self->out_arg;
   return;
}

sub has_in_args {
   my ($self, $location) = @_;

   for my $arg (@{$self->in_args}) {
      return TRUE if $arg->location eq $location;
   }

   return FALSE;
}

sub route_display {
   my $self = shift;

   (my $route = $self->route) =~ s{ \{ (\w+) : [^\}]* \} }{:$1}gmx;

   return $route;
}

sub route_match {
   my $self = shift;

   (my $route = $self->route) =~ s{ \{[^\}]+\} }{\*}gmx;

   return $route;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Method - One-line description of the modules purpose


=head1 Synopsis

   use Web::Components::API::Method;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

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
