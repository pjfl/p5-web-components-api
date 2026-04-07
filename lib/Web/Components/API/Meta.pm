package Web::Components::API::Meta;

use Unexpected::Types qw( ArrayRef );
use Moo;
use MooX::HandlesVia;

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Meta - Meta class

=head1 Synopsis

   use Web::Components::API::Meta;

=head1 Description

Meta class

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<column_list>

An array reference of L<Web::Components::Column> objects

Handles; C<add_to_column_list>, C<clear_column_list>, and C<has_column_list>
via the Array trait

=cut

has 'column_list' =>
   is            => 'rw',
   isa           => ArrayRef,
   default       => sub { [] },
   handles_via   => 'Array',
   handles       => {
      add_to_column_list => 'push',
      clear_column_list  => 'clear',
      has_column_list    => 'count',
   };

=item C<method_list>

An array reference of L<Web::Components::Method> objects

Handles; C<add_to_method_list>, C<clear_method_list>, and C<has_method_list>
via the Array trait

=cut

has 'method_list' =>
   is            => 'rw',
   isa           => ArrayRef,
   default       => sub { [] },
   handles_via   => 'Array',
   handles       => {
      add_to_method_list => 'push',
      clear_method_list  => 'clear',
      has_method_list    => 'count',
   };

=back

=head1 Subroutines/Methods

Defines no methods

=over 3

=cut

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
