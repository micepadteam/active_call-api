# Active Call - Api

Active Call - API is an extension of [Active Call](https://rubygems.org/gems/active_call) that provides a standardized way to create service objects for REST API endpoints.

Before proceeding, please review the [Active Call Usage](https://github.com/kobusjoubert/active_call?tab=readme-ov-file#usage) section. It takes just 55 seconds.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

Set up an `ActiveCall::Base` base service class for the REST API and include `ActiveCall::Api`.

```ruby
require 'active_call'
require 'active_call/api'

class YourGem::BaseService < ActiveCall::Base
  include ActiveCall::Api

  self.abstract_class = true

  ...
```

Implement a `connection` method to hold a [Faraday::Connection](https://lostisland.github.io/faraday/#/getting-started/quick-start?id=faraday-connection) object.

This connection instance will then be used in the `call` methods of the individual service objects.

```ruby
class YourGem::BaseService < ActiveCall::Base
  ...

  config_accessor :api_key, default: ENV['API_KEY'], instance_writer: false
  config_accessor :logger, default: Logger.new($stdout), instance_writer: false

  def connection
    @_connection ||= Faraday.new do |conn|
      conn.url_prefix = 'https://example.com/api/v1'
      conn.request :authorization, 'X-API-Key', api_key
      conn.request :json
      conn.response :json
      conn.response :logger, logger, formatter: Faraday::Logging::ColorFormatter, prefix: { request: 'YourGem', response: 'YourGem' } do |logger|
        logger.filter(/(Authorization:).*"(.+)."/i, '\1 [FILTERED]')
      end
      conn.adapter Faraday.default_adapter
    end
  end

  ...
```

You can now create a REST API service object like so.

```ruby
class YourGem::SomeResource::UpdateService < YourGem::BaseService
  attr_reader :id, :first_name, :last_name

  validates :id, :first_name, :last_name, presence: true

  def initialize(id:, first_name:, last_name:)
    @id         = id
    @first_name = first_name
    @last_name  = last_name
  end

  # PUT /api/v1/someresource/:id
  def call
    connection.put("someresource/#{id}", first_name: first_name, last_name: last_name)
  end
end
```

### Using `call`

```ruby
service = YourGem::SomeResource::UpdateService.call(id: '1', first_name: 'Stan', last_name: 'Marsh')
service.success? # => true
service.errors # => #<ActiveModel::Errors []>
service.response # => #<Faraday::Response ...>
service.response.status # => 200
service.response.body # => {}
```

### Using `call!`

```ruby
begin
  service = YourGem::SomeResource::UpdateService.call!(id: '1', first_name: 'Stan', last_name: '')
rescue ActiveCall::ValidationError => exception
  exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=last_name, type=blank, options={}>]>
  exception.errors.full_messages # => ["Last name can't be blank"]
rescue ActiveCall::UnprocessableEntityError => exception
  exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=unprocessable_entity, options={}>]>
  exception.errors.full_messages # => ["Unprocessable Entity"]
  exception.response # => #<Faraday::Response ...>
  exception.response.status # => 422
  exception.response.body # => {}
end
```

## Errors

The following exceptions will get raised when using `call!` and the request was unsuccessful.

| HTTP Status Code | Exception Class                                |
| :--------------: | ---------------------------------------------- |
|  **4xx**         | `ActiveCall::ClientError`                      |
|  **400**         | `ActiveCall::BadRequestError`                  |
|  **401**         | `ActiveCall::UnauthorizedError`                |
|  **403**         | `ActiveCall::ForbiddenError`                   |
|  **404**         | `ActiveCall::NotFoundError`                    |
|  **406**         | `ActiveCall::NotAcceptableError`               |
|  **407**         | `ActiveCall::ProxyAuthenticationRequiredError` |
|  **408**         | `ActiveCall::RequestTimeoutError`              |
|  **409**         | `ActiveCall::ConflictError`                    |
|  **422**         | `ActiveCall::UnprocessableEntityError`         |
|  **429**         | `ActiveCall::TooManyRequestsError`             |
|  **5xx**         | `ActiveCall::ServerError`                      |
|  **500**         | `ActiveCall::InternalServerError`              |
|  **501**         | `ActiveCall::NotImplementedError`              |
|  **502**         | `ActiveCall::BadGatewayError`                  |
|  **503**         | `ActiveCall::ServiceUnavailableError`          |
|  **504**         | `ActiveCall::GatewayTimeoutError`              |

**400..499** errors are subclasses of `ActiveCall::ClientError`.

**500..599** errors are subclasses of `ActiveCall::ServerError`.

For any explicit HTTP status code not listed here, an `ActiveCall::ClientError` exception gets raised for **4xx** HTTP status codes and an `ActiveCall::ServerError` exception for **5xx** HTTP status codes.

### Custom Exception Classes

If you want to use your error classes instead, override the `exception_mapping` class method.

```ruby
class YourGem::BaseService < ActiveCall::Base
  ...

  class << self
    def exception_mapping
      {
        validation_error:              YourGem::ValidationError,
        request_error:                 YourGem::RequestError,
        client_error:                  YourGem::ClientError,
        server_error:                  YourGem::ServerError,
        bad_request:                   YourGem::BadRequestError,
        unauthorized:                  YourGem::UnauthorizedError,
        forbidden:                     YourGem::ForbiddenError,
        not_found:                     YourGem::NotFoundError,
        not_acceptable:                YourGem::NotAcceptableError,
        proxy_authentication_required: YourGem::ProxyAuthenticationRequiredError,
        request_timeout:               YourGem::RequestTimeoutError,
        conflict:                      YourGem::ConflictError,
        unprocessable_entity:          YourGem::UnprocessableEntityError,
        too_many_requests:             YourGem::TooManyRequestsError,
        internal_server_error:         YourGem::InternalServerError,
        bad_gateway:                   YourGem::BadGatewayError,
        service_unavailable:           YourGem::ServiceUnavailableError,
        gateway_timeout:               YourGem::GatewayTimeoutError
      }
    end
  end

  ...
```

### Error Types

The methods below determine what **type** of error gets added to the **errors** object.

```ruby
service.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=bad_request, options={}>]>
```

When using `.call!`, they map to the `exception_mapping` above, so `bad_request?` maps to `bad_request`.

```ruby
exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=bad_request, options={}>]>
```

```ruby
class YourGem::BaseService < ActiveCall::Base
  ...

  def bad_request?
    response.status == 400
  end

  def unauthorized?
    response.status == 401
  end

  def forbidden?
    response.status == 403
  end

  def not_found?
    response.status == 404
  end

  def not_acceptable?
    response.status == 406
  end

  def proxy_authentication_required?
    response.status == 407
  end

  def request_timeout?
    response.status == 408
  end

  def conflict?
    response.status == 409
  end

  def unprocessable_entity?
    response.status == 422
  end

  def too_many_requests?
    response.status == 429
  end

  def internal_server_error?
    response.status == 500
  end

  def bad_gateway?
    response.status == 502
  end

  def service_unavailable?
    response.status == 503
  end

  def gateway_timeout?
    response.status == 504
  end
```

These methods can be overridden to add more rules when an API does not respond with the relevant HTTP status code.

A common occurrence is when an API returns an HTTP status code of 400 with an error message in the body for anything related to client errors, sometimes even for a resource that could not be found.

It is not required to override any of these methods since all **4xx** and **5xx** errors add a `client_error` or `server_error` type to the errors object, respectively.

While not required, handling specific errors based on their actual meaning makes for a happier development experience.

You have access to the full `Farady::Response` object set to the `response` attribute, so you can use `response.status` and `response.body` to determine the type of error.

Perhaps the API does not always respond with a **422** HTTP status code for unprocessable entity requests or a **404** HTTP status for resources not found.

```ruby
class YourGem::BaseService < ActiveCall::Base
  ...

  def not_found?
    response.status == 404 || (response.status == 400 && response.body['error_code'] == 'not_found')
  end

  def unprocessable_entity?
    response.status == 422 || (response.status == 400 && response.body['error_code'] == 'not_processable')
  end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kobusjoubert/active_call-api.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
