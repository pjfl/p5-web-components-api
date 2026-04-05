package Web::Components::API::Argument;

use Web::Components::API::Constants
                      qw( FALSE TRUE );
use Unexpected::Types qw( Enum HashRef NonEmptySimpleStr Str );
use Web::Components::API::Description;
use Moo;

my $locations = Enum[qw(body path query)];
my $types     = Enum[qw(array array_of_hash array_of_int bool datetime dbl
                        hash hash/array_of_hash int int/str str )];

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

has 'location' => is => 'ro', isa => $locations, default => 'query';

has 'name' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'fields' => is => 'ro', isa => Str, predicate => TRUE;

has 'type' => is => 'ro', isa => $types, required => TRUE;

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Argument - One-line description of the modules purpose


=head1 Synopsis

   use Web::Components::API::Argument;
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
