package Test::API::Artist;

use Web::Components::API::Constants
                 qw( API_META FALSE NUL TRUE );
use HTTP::Status qw( HTTP_CREATED HTTP_FORBIDDEN HTTP_NO_CONTENT );
use Moo;
use Web::Components::API::Moo;

extends 'Web::Components::API::Base';
with    'Web::Components::Role';

my $class = __PACKAGE__;

has '+moniker' => default => 'artist';

has '+result_class' => default => 'Artist';

has_api_column 'active' =>
   type        => 'bool',
   description => 'Is this artist still active.',
   methods     => {
      get => TRUE, search => TRUE, create => TRUE, update => TRUE
   };

has_api_column 'artistid' =>
   type        => 'int',
   description => 'The unique identifier for this artist.',
   methods     => { get => TRUE, search => TRUE };

has_api_column 'import_log_id' =>
   type        => 'int',
   description => 'Unique import ID assigned if this artist was imported.',
   methods     => { get => TRUE, search => TRUE };

has_api_column 'name' =>
   type        => 'str',
   description => 'The name of the artist.',
   methods     => { get => TRUE, search => TRUE };

has_api_column 'name' =>
   type        => 'str',
   description => 'The name of the artist. Maximum 255 characters.',
   methods     => { create => TRUE, update => TRUE },
   constraints => {
      actions  => {
         validate => 'Mandatory MatchingRegex ValidLength',
      },
      options  => {
         max_length => 255,
         min_length => 3,
         pattern    => '\A [0-9A-Za-z_ ]+ \z',
      },
   };

has_api_column 'upvotes' =>
   type        => 'int',
   description => 'Number of upvotes recieved by this artist.',
   methods     => {
      get => TRUE, search => TRUE, create => TRUE, update => TRUE
   };

has_api_column 'cds' =>
   related     => 'cd',
   type        => 'array_of_hash',
   description => 'CDS related to the artist.',
   methods     => { get => TRUE, search => TRUE };

has_api_method 'search' =>
   route       => '/artist',
   action      => 'search',
   access      => 'artist/list',
   description => q(
      Searches all artists, returning those matching your specified
      criteria as [% transport_type('array_of_hash') | indefinite_article %].
      You can supply any number of search criteria from the list shown.

      Optionally, you can paginate the output by passing page and page_size
      parameters.
   ),
   in_args     => [{
      name        => 'search',
      type        => 'hash',
      description => q(
         [% transport_type | ucfirst %] representing the values on which to
         search for matching artists.
      ),
      fields      => 'search',
      location    => 'query',
   }, $class->content_arguments, $class->pagination_arguments],
   out_arg      => {
      name        => 'artists',
      type        => 'array',
      description => q(
         Returns the found artists as
         [% transport_type('array_of_hash') | indefinite_article %].
      ),
      fields      => 'get',
   },
   examples    => [{
      name        => 'Get All Artists',
      description => 'Get all artists, limited to 1 per page',
      url         => '/artist?page_size=1',
      response    => [{
         artistid      => 1,
         name          => 'Deep Purple',
         active        => \1,
         upvotes       => 70,
         import_log_id => NUL,
      }],
   }];

has_api_method 'create' =>
   method       => 'POST',
   route        => '/artist',
   action       => 'create',
   access       => 'artist/create',
   success_code => HTTP_CREATED,
   message      => 'Artist [_1] created',
   description  => q(
      Creates a new artist. The return value is
      [% transport_type('hash') | indefinite_article %] containing your new
      artist, including its unique ID.
   ),
   in_args      => [{
      name        => 'create',
      type        => 'hash',
      description => 'Initial values for your new artist.',
      fields      => 'create',
      location    => 'body',
   }],
   out_arg      => {
      name        => 'artist',
      type        => 'hash',
      description => q(
         [% transport_type | indefinite_article | ucfirst %] representing
         the artist matching the given ID.
      ),
      fields      => 'get',
   },
   examples     => [{
      name     => 'Create an Artist',
      body     => {
         name    => 'Hawkwind',
         active  => \1,
         upvotes => 50,
      },
      response => {
         artist_id     => 2,
         name          => 'Hawkwind',
         active        => \1,
         upvotes       => 50,
         import_log_id => NUL,
      },
   }];

has_api_method 'get' =>
   route       => '/artist/{artistid:[0-9]+}',
   action      => 'get',
   access      => 'artist/view',
   description => q(
      Fetches an artist by ID, and returns
      [% transport_type('hash') | indefinite_article %] containing the details
      of that artist.
   ),
   in_args     => [{
      name        => 'artistid',
      type        => 'int',
      description => 'ID of the artist.',
      location    => 'path',
   }],
   out_arg     => {
      name        => 'artist',
      type        => 'hash',
      description => q(
         [% transport_type | indefinite_article | ucfirst %] representing
         the artist matching the given ID.
      ),
      fields      => 'get',
   },
   examples    => [{
      name        => 'Get Artist ID 1',
      url         => '/artist/1',
      response    => {
         artistid      => 1,
         name          => 'Deep Purple',
         active        => \1,
         upvotes       => 70,
         import_log_id => NUL,
      },
   }];

has_api_method 'update' =>
   method      => 'PUT',
   route       => '/artist/{artistid:[0-9]+}',
   action      => 'update',
   access      => 'artist/edit',
   message     => 'Artist [_1] updated',
   description => 'Updates one or more values for a given artist.',
   in_args     => [{
      name        => 'artistid',
      type        => 'int',
      description => 'ID of the artist you wish to update.',
      location    => 'path',
   },{
      name        => 'update',
      type        => 'hash',
      description => q(
         New values for the fields of your artist which you wish to
         change. Any values not present in this [% transport_type %] will be
         left unaltered.
      ),
      fields      => 'update',
      location    => 'body',
   }],
   out_arg     => {
      name        => 'artist',
      type        => 'hash',
      description => q(
         [% transport_type | indefinite_article | ucfirst %] representing
         the artist matching the given ID.
      ),
      fields      => 'get',
   },
   examples    => [{
      name     => 'Update an Artist',
      url      => '/artist/2',
      body     => { upvotes => 90 },
      response => {
         artistid      => 2,
         name          => 'Hawkwind',
         active        => \1,
         upvotes       => 90,
         import_log_id => NUL,
      },
   }];

has_api_method 'delete' =>
   method       => 'DELETE',
   route        => '/artist/{artistid:[0-9]+}',
   action       => 'delete',
   access       => 'artist/delete',
   success_code => HTTP_NO_CONTENT,
   message      => 'Artist [_1] deleted',
   description  => 'Delete the specified artist.',
   in_args      => [{
      name        => 'artistid',
      type        => 'int',
      description => 'ID of the artist you wish to delete.',
      location    => 'path',
   }],
   examples     => [{
      name => 'Delete an Artist',
      url  => '/artist/2',
   }];

use namespace::autoclean -except => API_META;

1;
