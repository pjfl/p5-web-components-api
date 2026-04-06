package Web::Components::API::Column;

use Web::Components::API::Constants
                      qw( FALSE TRUE );
use Unexpected::Types qw( ArrayRef Bool CodeRef Dict Enum HashRef
                          NonEmptySimpleStr Optional Str );
use Web::Components::API::Description;
use Moo;
use MooX::HandlesVia;

my $locations = Enum[qw(body path query)];
my $types     = Enum[qw(array array_of_hash array_of_int bool datetime dbl
                        hash hash/array_of_hash int int/str str )];

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Column - Defines the attributes for an API column

=head1 Synopsis

   use Web::Components::API::Column;

=head1 Description

Defines the attributes for an API column

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item constraints

=cut

has 'constraints' =>
   is          => 'ro',
   isa         => Dict[
      actions => Optional[Dict[ validate => Str ]],
      filters => Optional[HashRef],
      options => Optional[HashRef],
   ],
   handles_via => 'Hash',
   handles     => { has_constraints => 'count' },
   default     => sub { {} };

=item constraints_display

=cut

has 'constraints_display' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self    = shift;
      my $actions = $self->constraints->{actions} or return 'None';

      return $actions->{validate} ? $actions->{validate} : 'None';
   };

=item description

=item has_description

Predicate

=cut

has 'description' =>
   is        => 'lazy',
   isa       => Str,
   init_arg  => undef,
   predicate => TRUE,
   default   => sub {
      my $self = shift;
      my $args = { text => $self->_description, type => $self->type };
      my $desc = Web::Components::API::Description->new($args);

      return "${desc}";
   };

has '_description' =>
   is       => 'ro',
   isa      => Str,
   init_arg => 'description',
   default  => 'Undocumented';

=item getter

=item has_getter

Predicate

=cut

has 'getter' => is => 'ro', isa => CodeRef, predicate => TRUE;

=item location

=cut

has 'location' => is => 'ro', isa => $locations, default => 'query';

=item name

=cut

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

=item methods

=cut

has 'methods' => is => 'ro', isa => HashRef[Bool], default => sub { {} };

=item type

=cut

has 'type' => is => 'ro', isa => $types, required => TRUE;

=back

=head1 Subroutines/Methods

Defines no methods

=cut

use namespace::autoclean;

1;

__END__

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
