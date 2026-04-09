# Name

Web::Components::API - REST API for Web::Components applications

# Synopsis

    package MyApp::Controller::REST;

    use Web::Components::Util qw( build_routes );
    use Web::Components::API;
    use Web::Simple;

    with 'Web::Components::Role';
    with 'Web::Components::ReverseMap';

    has '+moniker' => default => 'rest';

    has 'api' =>
       is      => 'lazy',
       default => sub {
          my $self = shift;
          my $args = {
             api_config   => $self->api_config,
             config       => $self->config,
             json_parser  => $self->json_parser,
             log          => $self->log,
             redis_client => $self->redis_client,
             schema       => $self->schema,
          };

          return Web::Components::API->new($args);
       };

    has 'api_config' => is => 'lazy', default => sub { {} };

    sub dispatch_request { build_routes
       'POST + /authorise + ?*'    => 'rest/authorise',
       'POST + /access_token + ?*' => 'rest/access_token',
       'POST + /refresh + ?*'      => 'rest/refresh',
       shift->api->routes,
    }

# Description

REST API for [Web::Components](https://metacpan.org/pod/Web%3A%3AComponents) applications

The example above does not define the attributes used to instantiate the
[Web::Components::API](https://metacpan.org/pod/Web%3A%3AComponents%3A%3AAPI) object. A model with a `moniker` of `rest` is
also required. This should proxy the methods provided by this API object

# Configuration and Environment

Defines the following attributes;

- `access_token_lifetime`

    Length of time in seconds for which the access token is valid. Defaults
    to two hours

- `api_config`

    A hash reference of options used to provide defaults for other attributes

- `config`

    A required configuration object. Passed to the constructor which loads and
    instantiates API entities each of which must have [Web::Components::Role](https://metacpan.org/pod/Web%3A%3AComponents%3A%3ARole)
    applied which requires a `config` object

- `dispatch_prefix`

    A string which defaults to `rest/dispatch`. See the `routes` method

- `entity_list`

    A sorted list of entity names

- `entities`

    An array of objects that inherit from [Web::Components::API::Base](https://metacpan.org/pod/Web%3A%3AComponents%3A%3AAPI%3A%3ABase). These
    are loaded and instantiated from the classes found in the `API` directory
    of the `config`.`appclass` namespace

- `json_parser`

    A required JSON parsing object. Should provide `decode` and `encode` methods

- `log`

    A required logging object. Should provide `error` and `info` methods

- `max_page_size`

    Maximum number of objects to return in a single API call. Defaults to two
    hundred

- `max_req_per_min`

    Maximum number of requests per minute. Used to throttle clients. Defaults
    to five

- `redis_client`

    A required [Redis](https://metacpan.org/pod/Redis) client object. Should provide `del`, `get` and
    `set_with_ttl` methods

- `refresh_token_lifetime`

    Length of time in seconds for which the access token will be able to
    successfully call the refresh endpoint. Defaults to twelve hours. After this
    re-authorisation will needed. If set to zero an access token will continue to
    refresh indefinitely

- `request_token_lifetime`

    Length of time in seconds that the request token will be valid. Defaults
    to three minutes

- `route_match_prefix`

    A string which defaults to `/*`. See the `routes` method

- `route_prefix`

    A string used in the documentation output. Defaults to `rest/v1` where
    the `1` is the current API version number

- `schema`

    A required instance of [DBIx::Class::Schema](https://metacpan.org/pod/DBIx%3A%3AClass%3A%3ASchema)

- `secret`

    A string used to create and verify access tokens

- `versions`

    An array reference of version numbers currently supported. Defaults to
    `[1]`

# Subroutines/Methods

Defines the following methods;

- `authorise`

        $response = $self->authorise($context);

    Obtain a `request_token`. The response contains an HTTP status code and a hash
    reference which forms the body containing the token. Requires `username` and
    `password` on `context`.`request`.`body_parameters`. Requires `find_user`
    and `authenticate` on `context`

- `access_token`

        $response = $self->access_token($context);

    Exchanges a `request_token` for a JWT `access_token`

    The response contains an HTTP status code and a hash reference which forms the
    body containing the token. Obtains `request_token` from
    `context`.`request`.`body_parameters`

    The user object returned by `context`.`find_user` is expected to have an
    `api_claim` method which returns the claim hash reference. The keys/values in
    the claim hash reference are applied to `context`.`request`.`session` if the
    session object has attributes of the same name. This will enable
    `context`.`is_authorised` to obtain user identity information when it is
    called by the `dispatch` method

- `dispatch`

        $response = $self->dispatch($context, @args);

    Obtains `moniker/action` from `context`.`action`. Uses the `moniker` to get
    the API entity and then calls `action` on that object. Requires a valid
    `access_token` on `context`.`request`.`headers`.`Authorization`. Requires
    `is_authorised` on `context`. The `args` are the positional parameters from
    the request. The first argument should be the version from the request path
    (defaults to v1)

- `get_entity`

        $entity_object = $self->get_entity($moniker);

    All API entities must do [Web::Components::Role](https://metacpan.org/pod/Web%3A%3AComponents%3A%3ARole) which gives them a unique
    attribute `moniker`. Returns the entity object for the given `moniker`

- `refresh`

        $response = $self->refresh($context);

    Obtains a fresh `access_token`

    The response contains an HTTP status code and a hash reference which forms the
    body containing the token. Requires a valid `access_token` from
    `context`.`request`.`headers`.`Authorization`

    An `access_token` will only refresh for the `refresh_token_lifetime`, after
    that re-authorisation will be required

- `routes`

        @routes = $self->routes;

    This should be called from within a [Web::Simple](https://metacpan.org/pod/Web%3A%3ASimple) `dispatch_request` method.
    Returns a list of pairs of strings. Each pair is a [Web::Dispatch](https://metacpan.org/pod/Web%3A%3ADispatch) route and
    `moniker/method_chain` used by [Web::Components](https://metacpan.org/pod/Web%3A%3AComponents) to implement chained
    dispatch

# Diagnostics

None

# Dependencies

- [Web::Components](https://metacpan.org/pod/Web%3A%3AComponents)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Web-Components-API.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
