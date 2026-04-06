package Web::Components::API::Constants;

use strictures;
use parent 'Exporter::Tiny';

use Class::Usul::Cmd::Constants qw( );

our @EXPORT = qw( API_META );

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

Defines the following exported functions;

=over 3

=item import

=cut

sub import {
   my $class       = shift;
   my $global_opts = { $_[0] && ref $_[0] eq 'HASH' ? %{+ shift } : () };
   my @wanted      = @_;
   my $usul_const  = {}; $usul_const->{$_} = 1 for (@wanted);
   my @self        = ();

   for (@EXPORT) { push @self, $_ if delete $usul_const->{$_} }

   $global_opts->{into} ||= caller;
   Class::Usul::Cmd::Constants->import($global_opts, keys %{$usul_const});
   $class->SUPER::import($global_opts, @self);
   return;
}

=item API_META

=cut

sub API_META () { '_api_meta_' }

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Constants>

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
