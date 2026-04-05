package Web::Components::API::Moo;

use mro;
use strictures;

use Web::Components::API::Constants
                          qw( API_META EXCEPTION_CLASS FALSE TRUE );
use Ref::Util             qw( is_arrayref );
use Sub::Install          qw( install_sub );
use Unexpected::Functions qw( throw );
use Web::Components::API::Column;
use Web::Components::API::Method;
use Web::Components::API::Meta;

my @banished_keywords = ( API_META );

my @block_attributes  = qw();
my @page_attributes   = qw();

sub import {
   my ($class, @args) = @_;

   my $target = caller;
   my @target_isa = @{ mro::get_linear_isa($target) };
   my $method = API_META;
   my $meta;

   if (@target_isa) {
      # Don't add this to a role. The ISA of a role is always empty!
      if ($target->can($method)) { $meta = $target->$method }
      else {
         $meta = Web::Components::API::Meta->new({ target => $target, @args });

         install_sub { as => $method, into => $target, code => sub {
            return $meta;
         }, };
      }
   }
   else {
      throw 'No meta object' unless $target->can($method);

      $meta = $target->$method;
   }

   my $rt_info_key = 'non_methods';
   my $info = $Role::Tiny::INFO{ $target };

   my $has_column = sub {
      my ($arg, %attributes) = @_;

      my $names = is_arrayref $arg ? $arg : [$arg];

      for my $name (@{$names}) {
         _assert_no_banished_keywords($target, $name);

         my $args   = { name => $name, %attributes };
         my $object = Web::Components::API::Column->new($args);

         $meta->add_to_column_list($object);
      }

      return;
   };

   $info->{$rt_info_key}{has_api_column} = $has_column if $info;

   install_sub { as => 'has_api_column', into => $target, code => $has_column };

   my $has_method = sub {
      my ($arg, %attributes) = @_;

      my $names = is_arrayref $arg ? $arg : [$arg];

      for my $name (@{$names}) {
         _assert_no_banished_keywords($target, $name);

         my $args   = { name => $name, %attributes };
         my $object = Web::Components::API::Method->new($args);

         $meta->add_to_method_list($object);
      }

      return;
   };

   $info->{$rt_info_key}{has_api_method} = $has_method if $info;

   install_sub { as => 'has_api_method', into => $target, code => $has_method };

   return;
}

# Private functions
sub _assert_no_banished_keywords {
   my ($target, $name) = @_;

   for my $ban (grep { $_ eq $name } @banished_keywords) {
      throw 'Method [_1] used by class [_2] as an attribute', [$ban, $target];
   }

   return;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Moo - One-line description of the modules purpose


=head1 Synopsis

   use Web::Components::API::Moo;
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
