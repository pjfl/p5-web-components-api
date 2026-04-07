package Web::Components::API::Column;

use Web::Components::API::Constants
                      qw( DATA_TYPES FALSE TRUE LOCATIONS );
use Unexpected::Types qw( ArrayRef Bool CodeRef Dict Enum HashRef
                          NonEmptySimpleStr Optional Str );
use Web::Components::API::Description;
use Moo;
use MooX::HandlesVia;

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

=item C<constraints>

A C<Dict> defining constraints that are applied to this column value

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

=item C<constraints_display>

Display string for the constraints in the documentation

=cut

has 'constraints_display' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self    = shift;
      my $actions = $self->constraints->{actions} or return 'None';

      return $actions->{validate} ? $actions->{validate} : 'None';
   };

=item C<description>

A text description of this column

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
      my $args = { text => $self->_description, type => $self->type };
      my $desc = Web::Components::API::Description->new($args);

      return "${desc}";
   };

has '_description' =>
   is       => 'ro',
   isa      => Str,
   init_arg => 'description',
   default  => 'Undocumented';

=item C<getter>

Optional code reference. If present when this column is serialised it will
be called and it's return value used instead of the raw column value

=item C<has_getter>

Predicate

=cut

has 'getter' => is => 'rw', isa => CodeRef, predicate => TRUE;

=item C<location>

Must be one of the C<LOCATIONS> exported by L<Web::Components::API::Constants>.
Defaults to C<query>

=cut

has 'location' => is => 'ro', isa => Enum[LOCATIONS], default => 'query';

=item C<name>

The name of this column. Required

=cut

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

=item C<methods>

A hash reference of booleans. Keys present are C<method> names and their
presence denotes that this column is to be included when that method is
called

=cut

has 'methods' => is => 'ro', isa => HashRef[Bool], default => sub { {} };

=item C<related>

The C<moniker> for the related API object. Used to identify the columns
that are serialised for related objects

=cut

has 'related' => is => 'ro', isa => Str, trigger => TRUE;

=item C<type>

The data type for this column. Must be one of the C<DATA_TYPES> exported
by L<Web::Components::API::Constants>

=cut

has 'type' => is => 'ro', isa => Enum[DATA_TYPES], required => TRUE;

=back

=head1 Subroutines/Methods

Defines no methods

=cut

#Private methods
sub _trigger_related {
   my ($self, $value) = @_;

   my $name = $self->name;

   $self->getter(sub { shift->_serialise_related($value, $name, @_) });
   return;
}

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
