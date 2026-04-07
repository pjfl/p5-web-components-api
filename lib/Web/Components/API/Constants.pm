package Web::Components::API::Constants;

use strictures;
use parent 'Exporter::Tiny';

use Web::ComposableRequest::Constants qw( );

our @EXPORT = qw( API_META DATA_TYPES HTTP_METHODS LOCATIONS );

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Constants - Exports the constants used in the distribution


=head1 Synopsis

   use Web::Components::API::Constants qw( API_META );

=head1 Description

Exports the constants used in the distribution

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Exports the following functions/constants;

=over 3

=item C<import>

Any requested subroutines not exported here are passed to
L<Web::ComposableRequest::Constants>. If it does not export them an
exception is raised

=cut

sub import {
   my $class       = shift;
   my $global_opts = { $_[0] && ref $_[0] eq 'HASH' ? %{+ shift } : () };
   my @wanted      = @_;
   my $usul_const  = {}; $usul_const->{$_} = 1 for (@wanted);
   my @self        = ();

   for (@EXPORT) { push @self, $_ if delete $usul_const->{$_} }

   $global_opts->{into} ||= caller;
   Web::ComposableRequest::Constants->import($global_opts, keys %{$usul_const});
   $class->SUPER::import($global_opts, @self);
   return;
}

=item C<API_META>

Attribute used to store the meta object on the consuming class

=cut

sub API_META () { '_api_meta_' }

=item C<DATA_TYPES>

List of data types understood by the column/argument object

=cut

sub DATA_TYPES () { qw(array array_of_hash array_of_int bool datetime dbl
                       hash hash/array_of_hash int int/str str ) }

=item C<HTTP_METHODS>

List of supported HTTP methods

=cut

sub HTTP_METHODS () { qw( GET PUT POST DELETE ) }

=item C<LOCATIONS>

List of locations for input parameters

=cut

sub LOCATIONS () { qw(body path query) }

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Web::ComposableRequest::Constants>

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
