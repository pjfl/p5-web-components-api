package Web::Components::API::Base;

use Web::Components::API::Constants
                               qw( API_META EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status               qw( HTTP_FORBIDDEN HTTP_NOT_FOUND
                                   HTTP_UNPROCESSABLE_ENTITY is_error );
use Unexpected::Types          qw( ArrayRef Int Str );
use List::Util                 qw( first );
use Ref::Util                  qw( is_arrayref is_hashref is_scalarref );
use Scalar::Util               qw( blessed );
use Type::Utils                qw( class_type );
use Unexpected::Functions      qw( throw );
use Web::Components::API::Util qw( json_bool );
use Data::Validation;
use Web::Components::API::Column;
use Moo;

has 'column_list' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub {
      my $self = shift;

      return [Web::Components::API::Column->new({
         name        => 'page',
         type        => 'int',
         description => 'Page number',
         location    => 'query',
         methods     => { pagination => TRUE },
      }), Web::Components::API::Column->new({
         name        => 'page_size',
         type        => 'int',
         description => 'Page size',
         location    => 'query',
         methods     => { pagination => TRUE },
      }), Web::Components::API::Column->new({
         name        => 'sort_by',
         type        => 'str',
         description => 'Sort order',
         location    => 'query',
         methods     => { pagination => TRUE },
      }), @{$self->_get_meta->column_list}];
   };

has 'max_page_size' => is => 'ro', isa => Int, default => 250;

has 'method_list' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { shift->_get_meta->method_list };

has 'schema' =>
   is       => 'ro',
   isa      => class_type('DBIx::Class::Schema'),
   required => TRUE;

has 'result_class' => is => 'ro', isa => Str, required => TRUE;

has 'resultset' =>
   is      => 'lazy',
   isa     => class_type('DBIx::Class::ResultSet'),
   default => sub {
      my $self = shift;

      return $self->schema->resultset($self->result_class);
   };

sub arguments_pageing {
   return {
      name        => 'paging',
      type        => 'hash',
      description => q(
         Optional [% transport_type %] containing pagination options.
      ),
      fields      => 'pagination',
      location    => 'query',
   };
}

sub create {
   my ($self, $context) = @_;

   $self->_check_permission($context, 'create');

   my $params  = $context->request->body_parameters;
   my $options = $self->_filter_params($context, 'create', $params);

   $self->_validate_constraints('create', $options);

   my $result  = $self->resultset->create($options);
   my $code    = $self->_success_code('create');
   my $id      = $result->id;

   $result->discard_changes;
   $result = $self->get($context, $id);
   $result = [$code, $result->[1]] unless is_error($result->[0]);
   $result->[2] = $id;
   return $result;
}

sub delete {
   my ($self, $context, @args) = @_;

   $self->_check_permission($context, 'delete');

   my $id     = $args[0];
   my $result = $self->resultset->find_by_key($id) or $self->_not_found($id);

   $result->delete;

   return [$self->_success_code('delete'), {}, $id];
}

sub get {
   my ($self, $context, @args) = @_;

   $self->_check_permission($context, 'get');

   my $id     = $args[0];
   my $result = $self->resultset->find_by_key($id) or $self->_not_found($id);

   return [$self->_success_code('get'), $self->_serialise('get', $result)];
}

sub search {
   my ($self, $context) = @_;

   $self->_check_permission($context, 'search');

   my $params  = $context->request->query_parameters;
   my $where   = $self->_build_where($context, $params);
   my $options = $self->_build_options($context, $params);
   my $rs      = $self->resultset->search($where, $options);
   my $code    = $self->_success_code('search');

   return [$code, $self->_serialise('search', $rs)];
}

sub update {
   my ($self, $context, @args) = @_;

   $self->_check_permission($context, 'update');

   my $id      = $args[0];
   my $result  = $self->resultset->find_by_key($id) or $self->_not_found($id);
   my $params  = $context->request->body_parameters;
   my $options = $self->_filter_params($context, 'update', $params);

   $self->_validate_constraints('update', $options);
   $result->update($options);
   $result->discard_changes;
   $result = $self->get($context, $id);
   $result->[2] = $id;

   return $result;
}

sub fields {
   my ($self, $object) = @_;

   my $name = $object->fields or return [];
   my @columns;

   for my $column (@{$self->column_list}) {
      push @columns, $column if $column->methods->{$name};
   }

   return \@columns;
}

sub get_message {
   my ($self, $method_name, $id) = @_;

   my $message = $self->_find_method($method_name)->message;

   $message =~ s{ \[_1\] }{'$id'}mx if $id;

   return $message;
}

# Private methods
sub _build_clause {
   my ($self, $table, $col, $value) = @_;

   my $quoted_col = _quote_column_name($table, $col);

   if (defined $value) {
      if ($value eq NUL) {
         return $self->_combine_where_clauses(
            'OR', [ [$col => $value], [$col => undef] ]
         );
      }
      elsif ($value =~ m{ \D }mx) {
         $value = [$col, lc $value];
         $col   = "LOWER(${quoted_col}) = ?";
         return \[$col => $value];
      }
   }

   return ("${table}.${col}" => $value);
}

sub _build_options {
   my ($self, $context, $params) = @_;

   my $max_size = $self->max_page_size;
   my $page     = $params->{page} // 1;
   my $size     = $params->{page_size} // $max_size;
   my $rv       = HTTP_UNPROCESSABLE_ENTITY;
   my $order;

   throw 'Argument [_1] invalid', args => ['page'], rv => $rv
      unless $page =~ m{ \A [0-9]+ \z }mx && $page > 0;

   throw 'Argument [_1] invalid', args => ['page_size'], rv => $rv
      unless $size =~ m{ \A [0-9]+ \z }mx && $size >= 1 && $size <= $max_size;

   if ($params->{sort_by}) {
      my ($column, $dirn) = split m{ [ ] }mx, $params->{sort_by};

      $dirn = 'asc' unless $dirn;

      throw 'Argument [_1] invalid', args => ['sort_by'], rv => $rv
         unless $column && $dirn =~ m{ \A (asc)|(desc) \z }imx;

      $order = { "-${dirn}" => "me.${column}" };
   }

   my $options = { page => $page, rows => $size };

   $options->{order_by} = $order if $order;

   return $options;
}

sub _build_where {
   my ($self, $context, $params, $name) = @_;

   my $where = {};
   my @clauses;

   $where = $self->_filter_params($context, 'search', $params) if $params;
   $name //= 'me';

   for my $col (keys %{$where}) {
      my $value = $where->{$col};

      if (ref $value) {
         if (is_arrayref $value) {
            my @sub_clauses;

            for my $element (@{$value}) {
               push @sub_clauses, $self->_build_clause($name, $col, $element);
            }

            push @clauses, $self->_combine_clauses('OR', \@sub_clauses);
         }
         else {
            my $rv = HTTP_UNPROCESSABLE_ENTITY;

            throw 'Argument [_1] invalid', args => [$col], rv => $rv;
         }
      }
      else { push @clauses, $self->_build_clause($name, $col, $value) }
   }

   return scalar @clauses ? $self->_combine_clauses('AND', \@clauses) : {};
}

sub _check_permission {
   my ($self, $context, $method_name) = @_;

   my $api_method = $self->_find_method($method_name);

   throw 'No [_1] permission', args => [$method_name], rv => HTTP_FORBIDDEN
      unless $context->is_authorised($api_method->access);

   return;
}

sub _combine_clauses {
   my ($self, $operator, $clauses) = @_;

   $operator = lc $operator;

   if ($operator eq 'or') { return { -or => $clauses } }
   elsif ($operator eq 'and') { return { -and => $clauses } }

   return;
}

sub _filter_params {
   my ($self, $context, $method_name, $params) = @_;

   my %record;

   for my $column_name (keys %{$params}) {
      my $col = $self->_find_column($column_name, $method_name) or next;

      # Special case 1: If the column is declared as int, and
      # the Perl value is false and is NOT explicitly zero, then
      # the caller probably means NULL, so set the value to undef.
      # This enables, for example, searching on a NULL artistid
      my $column_nullable = $col->type eq 'int' ? TRUE : FALSE;

      # Special case 2: If the column is declared as int/str
      # then it's a user field that can be an ID /or/ en email.
      # Look it up if it's an email.
      if ($col->type eq 'int|str') {
         my $user = $context->find_user({ username => $params->{$column_name}});

         $params->{$column_name} = $user->id;
      }

      my $value = $params->{$column_name} // NUL;

      $value = "${value}" unless is_arrayref $value;
      $value = undef if $column_nullable && $value eq NUL;

      $record{$column_name} = $value;
   }

   return \%record;
}

sub _find_column {
   my ($self, $column_name, $method_name) = @_;

   return first { $_->name eq $column_name && $_->methods->{$method_name} }
               @{$self->column_list};
}

sub _find_method {
   my ($self, $method_name) = @_;

   my $api_method = first { $_->name eq $method_name } @{$self->method_list};

   throw 'Method [_1] unknown', [$method_name] unless $api_method;

   return $api_method;
}

sub _get_meta {
   my $self  = shift;
   my $class = blessed $self || $self;
   my $attr  = API_META;

   return $class->$attr;
}

sub _not_found {
   my ($self, $id) = @_;

   my $class = $self->result_class;

   throw "${class} [_1] not found", args => [$id], rv => HTTP_NOT_FOUND;
}

sub _serialise {
   my ($self, $method_name, $object) = @_;

   if (blessed $object) {
      if ($object->can('serialise_api')) {
         return $self->_serialise($method_name, $object->serialise_api);
      }
      elsif ($object->isa('DBIx::Class::ResultSet')) {
         return $self->_serialise($method_name, [$object->all]);
      }
      elsif ($object->isa('DBIx::Class')) {
         my $obj_columns = {};

         for my $col (@{$self->column_list}) {
            next unless $col->methods->{$method_name};

            my $field_name = $col->name;
            my $value;

            if ($col->has_getter) { $value = $col->getter->($object) }
            else { $value = $object->$field_name }

            $value = json_bool $value if $col->type && $col->type eq 'bool';

            $obj_columns->{$field_name} = $value;
         }

         return $self->_serialise($method_name, $obj_columns);
      }
      elsif ($object->isa('DateTime')) {
         $object->set_time_zone('UTC');
         return "${object}";
      }
      elsif ($object->isa('JSON::XS::Boolean')) {
         return $object;
      }
      elsif ($object->isa('JSON::PP::Boolean')) {
         return $object;
      }

      my $rv   = HTTP_UNPROCESSABLE_ENTITY;
      my $args = [blessed $object];

      throw 'Object [_1] cannot serialise', args => $args, rv => $rv;
   }
   elsif (is_arrayref $object) {
      return [ map { $self->_serialise($method_name, $_) } @{$object} ];
   }
   elsif (is_hashref $object) {
      my %hash;

      for my $key (keys %{$object}){
         $hash{$key} = $self->_serialise($method_name, $object->{$key});
      }

      return \%hash;
   }
   elsif (is_scalarref $object) {
      return $object;
   }
   elsif (defined $object) {
      return $object;
   }

   return;
}

sub _success_code {
   my ($self, $method_name) = @_;

   return $self->_find_method($method_name)->success_code;
}

sub _validate_constraints {
   my ($self, $method_name, $options) = @_;

   my @constrained = grep { $_->has_constraints && $_->methods->{$method_name} }
                         @{ $self->column_list };

   for my $column (@constrained) {
      my $col_name    = $column->name;

      next unless exists $options->{$col_name} || $method_name eq 'create';

      my $constraints = $column->constraints;
      my $actions     = _qualify_constraint_actions($constraints->{actions});
      my $args        = {
         constraints => { $col_name => $constraints->{options} // {} },
         fields      => { $col_name => $actions // {} },
         filters     => { $col_name => $constraints->{filters} // {} },
      };
      my $dv_obj = Data::Validation->new($args);
      my $value  = $dv_obj->check_field($col_name, $options->{$col_name});

      $options->{$col_name} = $value;
   }

   return;
}

# Private functions
sub _qualify_constraint_actions {
   my $actions  = shift;
   my $validate = NUL;

   for my $role (split m{ [ ] }mx, $actions->{validate} // NUL) {
      $validate .= ($validate ? q( ) : NUL) . "is${role}";
   }

   return { %{$actions}, validate => $validate };
}

sub _quote_column_name {
   my @parts = @_;

   my $rv = HTTP_UNPROCESSABLE_ENTITY;

   for my $part (@parts) {
      throw 'Invalid column name. Column must not be empty', rv => $rv
         unless $part;

      throw 'Invalid column name. Found double quote', rv => $rv
         if $part =~ m{ " }mx;

      $part = sprintf '"%s"', $part;
   }

   return join q(.), @parts;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Base - One-line description of the modules purpose


=head1 Synopsis

   use Web::Components::API::Base;
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
