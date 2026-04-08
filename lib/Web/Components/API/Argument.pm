package Web::Components::API::Argument;

use Web::Components::API::Constants
                      qw( DATA_TYPES FALSE TRUE LOCATIONS );
use Unexpected::Types qw( Enum HashRef NonEmptySimpleStr Str );
use Web::Components::API::Description;
use Moo;

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Argument - Defines an API argument

=head1 Synopsis

   use Web::Components::API::Argument;

=head1 Description

Defines an API argument

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<description>

A text description of this argument

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

=item C<location>

Must be one of the C<LOCATIONS> exported by L<Web::Components::API::Constants>.
Defaults to C<query>

=cut

has 'location' => is => 'ro', isa => Enum[LOCATIONS], default => 'query';

=item C<name>

The name of this argument. Required

=cut

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

=item C<fields>

Key used by the documentation method C<fields> in the base class

=item C<has_fields>

Predicate

=cut

has 'fields' => is => 'ro', isa => Str, predicate => TRUE;

=item C<type>

The data type for this column. Must be one of the C<DATA_TYPES> exported
by L<Web::Components::API::Constants>

=cut

has 'type' => is => 'ro', isa => Enum[DATA_TYPES], required => TRUE;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item BUILD

Force the lazy attributes to evaluate

=cut

sub BUILD {
   my $self = shift;

   $self->description;
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Unexpected>

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
