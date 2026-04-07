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

=pod

=encoding utf-8

=head1 Name

Web::Components::API::Base - Base class for exposed entities

=head1 Synopsis

   package MyApp::API::MyEntity;

   use Web::Components::API::Constants qw( API_META );
   use Moo;
   use Web::Components::API::Moo;

   extends 'Web::Components::API::Base';
   with    'Web::Components::Role';

   has '+moniker' => default => 'myentity';

   has '+result_class' => default => 'MyResultClass';

   has_api_column 'column_name' => type => ...;

   has_api_method 'method_name' => route => ...;

   use namespace::autoclean -except => API_META;

=head1 Description

Base class for exposed entities. All C<API> classes are expected to inherit
from this

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<application>

An immutable weak reference to the L<Web::Components::API> object. Required

=cut

has 'application' => is => 'ro', required => TRUE, weak_ref => TRUE;

=item C<column_list>

The list of L<Web::Components::API::Column> objects declared for this entity

=cut

has 'column_list' =>
   is      => 'lazy',
   isa     => ArrayRef[class_type('Web::Components::API::Column')],
   default => sub {
      my $self = shift;

      return [
         @{$self->_content_columns},
         @{$self->_pagination_columns},
         @{$self->_get_meta->column_list},
      ];
   };

has '_content_columns' =>
   is      => 'ro',
   isa     => ArrayRef[class_type('Web::Components::API::Column')],
   default => sub {
      return [
         Web::Components::API::Column->new({
            name        => 'prefetch',
            type        => 'str',
            description => 'Include related entities',
            location    => 'query',
            methods     => { content => TRUE },
         }),
      ];
   };

has '_pagination_columns' =>
   is      => 'ro',
   isa     => ArrayRef[class_type('Web::Components::API::Column')],
   default => sub {
      return [
         Web::Components::API::Column->new({
            name        => 'page',
            type        => 'int',
            description => 'Page number',
            location    => 'query',
            methods     => { pagination => TRUE },
         }),
         Web::Components::API::Column->new({
            name        => 'page_size',
            type        => 'int',
            description => 'Page size',
            location    => 'query',
            methods     => { pagination => TRUE },
         }),
         Web::Components::API::Column->new({
            name        => 'sort_by',
            type        => 'str',
            description => 'Sort order',
            location    => 'query',
            methods     => { pagination => TRUE },
         }),
      ];
   };

=item C<max_page_size>

Maximum number of objects to return in a single API call. Defaults to 250

=cut

has 'max_page_size' => is => 'ro', isa => Int, default => 250;

=item C<method_list>

The list of L<Web::Components::API::Method> objects declared for this entity

=cut

has 'method_list' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { shift->_get_meta->method_list };

=item C<schema>

A required instance of a L<DBIx::Class> schema object

=cut

has 'schema' =>
   is       => 'ro',
   isa      => class_type('DBIx::Class::Schema'),
   required => TRUE;

=item C<result_class>

Required L<DBIx::Class> result class name. See C<resultset>

=cut

has 'result_class' => is => 'ro', isa => Str, required => TRUE;

=item C<resultset>

Derived from the C<schema> and C<result_class>. The C<resultset> object is
expected to implement the method C<find_by_key>

=cut

has 'resultset' =>
   is      => 'lazy',
   isa     => class_type('DBIx::Class::ResultSet'),
   default => sub {
      my $self = shift;

      return $self->schema->resultset($self->result_class);
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<content_arguments>

Class method. Add these to a methods C<in_args> to include the attributes
that they define

=cut

sub content_arguments {
   return {
      name        => 'content',
      type        => 'hash',
      description => q(
         Optional [% transport_type %] containing content fetching options.
      ),
      location    => 'query',
      fields      => 'content',
   }
}

=item C<pagination_arguments>

Class method. Add these to a methods C<in_args> to include the attributes
that they define

=cut

sub pagination_arguments {
   return {
      name        => 'paging',
      type        => 'hash',
      description => q(
         Optional [% transport_type %] containing pagination options.
      ),
      location    => 'query',
      fields      => 'pagination',
   };
}

=item C<create>

   $tuple = $self->create($context);

Creates a new persisted L<DBIx::Class> result object. Expects
C<context>.C<request>.C<body_parameters> to contains the attributes and
values used to create to object. Returns a tuple containing HTTP status
code, response body, and the id of the newly created object

=cut

sub create {
   my ($self, $context) = @_;

   $self->_check_permission($context, 'create');

   my $params  = $context->request->body_parameters;
   my $options = $self->_filter_params($context, 'create', $params);

   $self->_validate_constraints('create', $options);

   my $result = $self->resultset->create($options);
   my $code   = $self->_success_code('create');
   my $id     = $result->id;

   $result->discard_changes;
   $result = $self->get($context, $id);
   $result = [$code, $result->[1]] unless is_error($result->[0]);
   $result->[2] = $id;
   return $result;
}

=item C<delete>

   $tuple = $self->delete($context, @args);

Deletes a persisted object identified by the first of the C<args> passed.
Returns a tuple containing an HTTP status code, an empty response body, and
the id of the deleted object

=cut

sub delete {
   my ($self, $context, @args) = @_;

   $self->_check_permission($context, 'delete');

   my $id     = $args[0];
   my $result = $self->resultset->find_by_key($id) or $self->_not_found($id);

   $result->delete;

   return [$self->_success_code('delete'), {}, $id];
}

=item C<get>

   $tuple = $self->get($context, @args);

Fetches a persisted object identified by the first of the C<args> passed.
Returns a tuple containing an HTTP status code, and a response body
containing the object attributes and values

=cut

sub get {
   my ($self, $context, @args) = @_;

   $self->_check_permission($context, 'get');

   my $id     = $args[0];
   my $result = $self->resultset->find_by_key($id) or $self->_not_found($id);

   return [$self->_success_code('get'), $self->_serialise('get', $result)];
}

=item C<search>

   $tuple = $self->search($context);

Returns an array of persisted object matching the search criteria which are
extracted from the request query parameters

=cut

sub search {
   my ($self, $context) = @_;

   $self->_check_permission($context, 'search');

   my $params  = $context->request->query_parameters;
   my $where   = $self->_build_where($context, $params);
   my $options = $self->_build_options($context, $params);
   my $rs      = $self->resultset->search($where, $options);
   my $body    = $self->_serialise('search', $rs, $options);

   return [$self->_success_code('search'), $body];
}

=item C<update>

   $tuple = $self->update($context, @args);

Updates an existsing persisted object. The first of the C<args> is the id of
the object being updated. Update parameters are taken from
C<context>.C<request>.C<body_parameters>. Returns the same tuple as the
C<get> method but adds the id of the updated object

=cut

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

=item C<fields>

   $columns = $self->fields($object);

Returns an array reference of column objects associated with the
C<object>.C<fields> value. Used to display API documentation

=cut

sub fields {
   my ($self, $object) = @_;

   my $name = $object->fields or return [];
   my @columns;

   for my $column (@{$self->column_list}) {
      next if $column->related;

      push @columns, $column if $column->methods->{$name};
   }

   return \@columns;
}

=item C<get_message>

   $message = $self->get_message($method_name, $id?);

Fetches the success information message for the given method. Substitutes
the optional id for the first positional parameter C<[_1]>. Returns the
message. Used as the log message for a successful operation

=cut

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

   my $options = {};
   my @columns = (@{$self->_pagination_columns}, @{$self->_content_columns});

   for my $col_name (map { $_->name } @columns) {
      my $build_method = "_build_options_${col_name}";

      $options = { %{$options}, %{$self->$build_method($params)}, };
   }

   return $options;
}

sub _build_options_page {
   my ($self, $params) = @_;

   my $page = $params->{page} // 1;
   my $rv   = HTTP_UNPROCESSABLE_ENTITY;

   throw 'Argument [_1] invalid', args => ['page'], rv => $rv
      unless $page =~ m{ \A [0-9]+ \z }mx && $page > 0;

   return { page => $page };
}

sub _build_options_page_size {
   my ($self, $params) = @_;

   my $max_size = $self->max_page_size;
   my $size     = $params->{page_size} // $max_size;
   my $rv       = HTTP_UNPROCESSABLE_ENTITY;

   throw 'Argument [_1] invalid', args => ['page_size'], rv => $rv
      unless $size =~ m{ \A [0-9]+ \z }mx && $size >= 1 && $size <= $max_size;

   return { rows => $size };
}

sub _build_options_prefetch {
   my ($self, $params) = @_;

   return {} unless $params->{prefetch};

   return { prefetch => $params->{prefetch} };
}

sub _build_options_sort_by {
   my ($self, $params) = @_;

   return {} unless $params->{sort_by};

   my ($column, $dirn) = split m{ [ ] }mx, $params->{sort_by};
   my $rv              = HTTP_UNPROCESSABLE_ENTITY;

   $dirn = 'asc' unless $dirn;

   throw 'Argument [_1] invalid', args => ['sort_by'], rv => $rv
      unless $column && $dirn =~ m{ \A (asc)|(desc) \z }imx;

   return { order_by => { "-${dirn}" => "me.${column}" } };
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
   my ($self, $method_name, $object, $options) = @_;

   if (blessed $object) {
      if ($object->can('serialise_api')) {
         my $value = $object->serialise_api;

         return $self->_serialise($method_name, $value, $options);
      }
      elsif ($object->isa('DBIx::Class::ResultSet')) {
         return $self->_serialise($method_name, [$object->all], $options);
      }
      elsif ($object->isa('DBIx::Class')) {
         my $obj_columns = {};

         for my $col (@{$self->column_list}) {
            next unless $col->methods->{$method_name};

            my $field_name = $col->name;
            my $value;

            if ($col->has_getter) {
               $value = $col->getter->($self, $method_name, $object, $options);
            }
            else { $value = $object->$field_name }

            next unless defined $value;

            $value = json_bool $value if $col->type && $col->type eq 'bool';

            $obj_columns->{$field_name} = $value;
         }

         return $self->_serialise($method_name, $obj_columns, $options);
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
      return [
         map { $self->_serialise($method_name, $_, $options) } @{$object}
      ];
   }
   elsif (is_hashref $object) {
      my %hash;

      for my $key (keys %{$object}){
         my $value = $object->{$key};

         $hash{$key} = $self->_serialise($method_name, $value, $options);
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

sub _serialise_related {
   my ($self, $moniker, $relation_name, $method_name, $object, $options) = @_;

   my $prefetch = $options->{prefetch};

   return unless $prefetch && $prefetch eq $relation_name;

   my $entity  = $self->application->get_entity($moniker);
   my $related = [$object->$relation_name->all];

   return $entity->_serialise($method_name, $related, $options);
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
      my $col_name = $column->name;

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

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Web::Components>

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
