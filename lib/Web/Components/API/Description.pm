package Web::Components::API::Description;

use overload '""' => sub { shift->_as_string }, fallback => 1;

use Web::Components::API::Constants qw( DATA_TYPES FALSE NUL TRUE );
use Unexpected::Types               qw( Enum HashRef Str );
use Web::ComposableRequest::Util    qw( trim );
use Moo;

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Description - Expands template directives in descriptions

=head1 Synopsis

   use Web::Components::API::Description;

=head1 Description

Expands template directives in descriptions. Does this when the object
reference is stringified

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<text>

A required non-empty string. The text of the description

=cut

my $non_empty_str = Str->where('length > 0');

has 'text' => is => 'ro', isa => $non_empty_str, required => TRUE;

=item C<type>

The data type for this description. Must be one of the C<DATA_TYPES> exported
by L<Web::Components::API::Constants>

=cut

has 'type' => is => 'ro', isa => Enum[DATA_TYPES];

has '_transport_types' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return {
         'array'         => { name => 'Array' },
         'array_of_hash' => {
            name => 'Array[Object]',
            text => 'array of objects',
         },
         'array_of_int'  => { name => 'Array[Integer]' },
         'bool'          => { name => 'Boolean' },
         'datetime'      => { name => 'DateTime' },
         'dbl'           => { name => 'Double' },
         'hash'          => { name => 'Object' },
         'hash/array_of_hash' => {
            name => 'Object|Array[Object]',
            text => 'object or array of objects',
         },
         'int'           => { name => 'Integer' },
         'str'           => { name => 'String' },
      };
   };

=back

=head1 Subroutines/Methods

Defines no methods

=over 3

=cut

# Private methods
sub _as_string {
   my $self         = shift;
   my $desc         = $self->text;
   my $translations = $self->_transport_types;
   my $directive_re = qr{ \[%\s*([^\]]*)%\] }mx;
   my @directives   = $desc =~ m{ $directive_re }gmx;

   for my $directive (@directives) {
      $directive =~ s{ \A \s+|\s+ \z }{}gmx;

      my ($inline_type) = $directive =~ m{ transport_type\('([^']*)'\) }mx;
      my $type   = $inline_type || $self->type;
      my $output = $translations->{$type}->{text}
                || $translations->{$type}->{name};

      if ($directive =~ m{ indefinite_article }mx) {
         my $article = $output =~ m{ ^[aeiou] }imx ? 'an' : 'a';

         $output = "${article} ${output}";
      }

      $output = ucfirst $output if $directive =~ m{ ucfirst }mx;

      $desc =~ s{ $directive_re }{$output}mx;
   }

   return trim $desc, "\n";
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
