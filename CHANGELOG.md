## [0.1.4] - 2025-05-07

- Update repository urls to activecall organization.

## [0.1.3] - 2025-04-02

- Added HTTP status code 410 Gone

## [0.1.2] - 2025-03-28

- Fix for when included in a Rails app when getting `<NoMethodError: undefined method 'attributes'`.

## [0.1.1] - 2025-03-27

- Remove `include ActiveModel::Validations`, it is already included with `active_call`.

## [0.1.0] - 2025-03-25

- Initial release.
- Initial `ActiveCall::*Error` classes with overridable `exception_mapping` and `connection` methods.
