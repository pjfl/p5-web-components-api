package Web::Components::API::Util;

use strictures;
use parent 'Exporter::Tiny';

use Digest                qw( );
use English               qw( -no_match_vars );
use File::DataClass::IO   qw( io );
use Unexpected::Functions qw( throw );

our @EXPORT = qw( create_token digest json_bool urandom );

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Util - API utility functions

=head1 Synopsis

   use Web::Components::API::Util qw( create_token );

=head1 Description

API utility functions

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Exports the following functions;

=over 3

=item C<create_token>

   $token = create_token;

Returns thirty two bytes of our very best random hexadecimal characters

=cut

sub create_token () {
   return substr digest(urandom())->hexdigest, 0, 32;
}

=item C<digest>

   $digest = digest $seed;

Return an instance of the best L<Digest> algorithm available to which
C<seed> has been added

=cut

my $digest_cache;

sub digest ($) {
   my $seed = shift;

   my ($candidate, $digest);

   if ($digest_cache) { $digest = Digest->new($digest_cache) }
   else {
      for (qw( SHA-512 SHA-256 SHA-1 MD5 )) {
         $candidate = $_;
         last if $digest = eval { Digest->new($candidate) };
      }

      throw 'Digest algorithm not found' unless $digest;
      $digest_cache = $candidate;
   }

   $digest->add($seed);

   return $digest;
}

=item C<json_bool>

   $scalar_ref = json_bool $scalar;

Evaluates the scalar value provided and returns references to true/false values
for serialising to JSON

=cut

sub json_bool ($) {
   return (shift) ? \1 : \0;
}

=item C<urandom>

   $random_bytes = urandom $wanted?, $options?;

Return random bytes. The optional C<wanted> defaults to sixty four characters,
and the optional hash reference C<options> defaults empty. Specify
C<options>.C<source> to set the path from which the random is read. If no
filesystem source is available, fallback on some pseudo-random material
instead

=cut

sub urandom (;$$) {
   my ($wanted, $opts) = @_;

   $wanted //= 64; $opts //= {};

   my $default = [q(), 'dev', $OSNAME eq 'freebsd' ? 'random' : 'urandom'];
   my $io      = io($opts->{source} // $default)->block_size($wanted);

   if ($io->exists and $io->is_readable and my $red = $io->read) {
      return ${ $io->buffer } if $red == $wanted;
   }

   my $res = q();

   while (length $res < $wanted) { $res .= _pseudo_random() }

   return substr $res, 0, $wanted;
}

sub _pseudo_random {
   return join q(), time, rand 10_000, $PID, {};
}

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Digest>

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
