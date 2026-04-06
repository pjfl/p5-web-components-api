# Name

Web::Components::API - REST API for Web::Components applications

# Synopsis

    use Web::Components::API;

# Description

REST API for Web::Components applications

# Configuration and Environment

Defines the following attributes;

- access\_token\_lifetime
- api\_config
- config
- dispatch\_prefix
- entity\_list
- entities
- json\_parser
- log
- max\_page\_size
- max\_req\_per\_min
- redis\_client
- request\_history
- request\_token\_lifetime
- route\_match\_prefix
- route\_prefix
- schema
- secret
- versions

# Subroutines/Methods

Defines the following methods;

- access\_token
- authorise
- dispatch
- get\_entity
- refresh
- routes

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
