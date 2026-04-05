package Web::Components::API::Description;

use overload '""' => sub { shift->_as_string }, fallback => 1;

use Web::Components::API::Constants qw( FALSE NUL TRUE );
use Unexpected::Types               qw( HashRef Str );
use Moo;

has 'text' => is => 'ro', isa => Str, required => TRUE;

has 'type' => is => 'ro', isa => Str;

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

   return $desc;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Description - One-line description of the modules purpose


=head1 Synopsis

   use Web::Components::API::Description;
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
