# frozen_string_literal: true

require 'active_call'
require 'faraday'
require 'faraday/retry'
require 'faraday/logging/color_formatter'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/error.rb")
loader.collapse("#{__dir__}/api/concerns")
loader.push_dir("#{__dir__}", namespace: ActiveCall)
loader.setup

require_relative 'error'
require_relative 'api/version'

module ActiveCall::Api
  extend ActiveSupport::Concern

  included do
    include ActiveModel::Validations

    validate on: :response do
      throw :abort if response.is_a?(Enumerable)

      # ==== 5xx
      errors.add(:base, :not_implemented)               and throw :abort if not_implemented?
      errors.add(:base, :bad_gateway)                   and throw :abort if bad_gateway?
      errors.add(:base, :service_unavailable)           and throw :abort if service_unavailable?
      errors.add(:base, :gateway_timeout)               and throw :abort if gateway_timeout?
      errors.add(:base, :internal_server_error)         and throw :abort if internal_server_error?

      # We'll use `server_error` for every 5xx error that we don't have an explicit exception class for.
      errors.add(:base, :server_error)                  and throw :abort if response.status >= 500

      # ==== 4xx
      errors.add(:base, :unauthorized)                  and throw :abort if unauthorized?
      errors.add(:base, :forbidden)                     and throw :abort if forbidden?
      errors.add(:base, :not_found)                     and throw :abort if not_found?
      errors.add(:base, :proxy_authentication_required) and throw :abort if proxy_authentication_required?
      errors.add(:base, :request_timeout)               and throw :abort if request_timeout?
      errors.add(:base, :conflict)                      and throw :abort if conflict?
      errors.add(:base, :unprocessable_entity)          and throw :abort if unprocessable_entity?
      errors.add(:base, :too_many_requests)             and throw :abort if too_many_requests?

      # Check for bad_request here since some APIs will use status 400 as a general response for all errors.
      errors.add(:base, :bad_request)                   and throw :abort if bad_request?

      # We'll use `client_error` for every 4xx error that we don't have an explicit exception class for.
      errors.add(:base, :client_error)                  and throw :abort if response.status >= 400
    end

    private

    # Used in Enumerable subclasses when retrieving paginated lists from an API endpoint.
    delegate :exception_for, to: :class
  end

  class_methods do
    EXCEPTION_MAPPING = {
      validation_error:              ActiveCall::ValidationError,
      request_error:                 ActiveCall::RequestError,
      client_error:                  ActiveCall::ClientError,
      server_error:                  ActiveCall::ServerError,
      bad_request:                   ActiveCall::BadRequestError,
      unauthorized:                  ActiveCall::UnauthorizedError,
      forbidden:                     ActiveCall::ForbiddenError,
      not_found:                     ActiveCall::NotFoundError,
      not_acceptable:                ActiveCall::NotAcceptableError,
      proxy_authentication_required: ActiveCall::ProxyAuthenticationRequiredError,
      request_timeout:               ActiveCall::RequestTimeoutError,
      conflict:                      ActiveCall::ConflictError,
      unprocessable_entity:          ActiveCall::UnprocessableEntityError,
      too_many_requests:             ActiveCall::TooManyRequestsError,
      internal_server_error:         ActiveCall::InternalServerError,
      not_implemented:               ActiveCall::NotImplementedError,
      bad_gateway:                   ActiveCall::BadGatewayError,
      service_unavailable:           ActiveCall::ServiceUnavailableError,
      gateway_timeout:               ActiveCall::GatewayTimeoutError
    }.freeze

    # If you want to use your error classes instead, overwrite the `exception_mapping` class method.
    #
    # ==== Examples
    #
    #   class YourGem::BaseService < ActiveCall::Base
    #     class << self
    #       def exception_mapping
    #         {
    #           validation_error: YourGem::ValidationError,
    #           request_error:    YourGem::RequestError,
    #           client_error:     YourGem::ClientError,
    #           server_error:     YourGem::ServerError,
    #           bad_request:      YourGem::BadRequestError,
    #           unauthorized:     YourGem::UnauthorizedError,
    #           ...
    #         }
    #       end
    #
    def exception_mapping
      EXCEPTION_MAPPING
    end

    # Using `call`.
    #
    # ==== Examples
    #
    #   service = YourGem::SomeResource::UpdateService.call(id: '1', first_name: 'Stan', last_name: 'Marsh')
    #   service.success? # => true
    #   service.errors # => #<ActiveModel::Errors []>
    #   service.response # => #<Faraday::Response ...>
    #   service.response.status # => 200
    #   service.response.body # => {}
    #
    # Using `call!`.
    #
    # ==== Examples
    #
    #   begin
    #     service = YourGem::SomeResource::UpdateService.call!(id: '1', first_name: 'Stan', last_name: '')
    #   rescue ActiveCall::ValidationError => exception
    #     exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=last_name, type=blank, options={}>]>
    #     exception.errors.full_messages # => ["Last name can't be blank"]
    #   rescue ActiveCall::UnprocessableEntityError => exception
    #     exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=unprocessable_entity, options={}>]>
    #     exception.errors.full_messages # => ["Unprocessable Entity"]
    #     exception.response # => #<Faraday::Response ...>
    #     exception.response.status # => 200
    #     exception.response.body # => {}
    #   end
    #
    def call!(...)
      super
    rescue ActiveCall::ValidationError => e
      raise api_validation_error(e)
    rescue ActiveCall::RequestError => e
      raise api_request_error(e)
    end

    def exception_for(response, errors, message = nil)
      exception_type = errors.details[:base].first[:error]

      case exception_type
      when *exception_mapping.keys
        exception_mapping[exception_type].new(response, errors, message)
      else
        exception_mapping[:request_error].new(response, errors, message)
      end
    end

    private

    def api_validation_error(exception)
      exception_mapping[:validation_error].new(exception.errors, exception.message)
    end

    def api_request_error(exception)
      exception_for(exception.response, exception.errors, exception.message)
    end
  end

  private

  # Subclasses must implement a `connection` method to hold a `Faraday::Connection` object.
  #
  # This connection instance will then be used in the `call` methods of the individual service objects.
  #
  # ==== Examples
  #
  #   class YourGem::BaseService < ActiveCall::Base
  #     config_accessor :api_key, default: ENV['API_KEY'], instance_writer: false
  #     config_accessor :logger, default: Logger.new($stdout), instance_writer: false
  #
  #     private
  #
  #     def connection
  #       @_connection ||= Faraday.new do |conn|
  #         conn.url_prefix = 'https://example.com/api/v1'
  #         conn.request :authorization, 'X-API-Key', api_key
  #         conn.request :json
  #         conn.response :json
  #         conn.response :logger, logger, formatter: Faraday::Logging::ColorFormatter, prefix: { request: 'YourGem', response: 'YourGem' } do |logger|
  #           logger.filter(/(Authorization:).*"(.+)."/i, '\1 [FILTERED]')
  #         end
  #         conn.adapter Faraday.default_adapter
  #       end
  #     end
  #
  # You can now create a REST API service object like so.
  #
  #   class YourGem::SomeResource::UpdateService < YourGem::BaseService
  #     attr_reader :id, :first_name, :last_name
  #
  #     validates :id, :first_name, :last_name, presence: true
  #
  #     def initialize(id:, first_name:, last_name:)
  #       @id         = id
  #       @first_name = first_name
  #       @last_name  = last_name
  #     end
  #
  #     # PUT /api/v1/someresource/:id
  #     def call
  #       connection.put("someresource/#{id}", first_name: first_name, last_name: last_name)
  #     end
  #   end
  #
  def connection
    raise NotImplementedError, 'Subclasses must implement a connection method. Must return a Faraday.new object.'
  end

  # The methods below determine what type of error gets added to the errors object.
  #
  #   service.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=bad_request, options={}>]>
  #
  # When using `.call!`, they map to the `exception_mapping` above, so `bad_request?` maps to `bad_request`.
  #
  #   exception.errors # => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=bad_request, options={}>]>
  #
  # These methods can be overridden to add more rules when an API does not respond with the relevant HTTP status code.
  #
  # A common occurrence is when an API returns an HTTP status code of 400 with an error message in the body for anything
  # related to client errors, sometimes even for a resource that could not be found.
  #
  # It is not required to overwrite any of these methods since all 4xx and 5xx errors add a `client_error` or
  # `server_error` type to the errors object, respectively.
  #
  # While not required, handling specific errors based on their actual meaning makes for a happier development
  # experience.
  #
  # You have access to the full `Farady::Response` object set to the `response` attribute, so you can use
  # `response.status` and `response.body` to determine the type of error.
  #
  # Perhaps the API does not always respond with a 422 HTTP status code for unprocessable entity requests or a 404 HTTP
  # status for resources not found.
  #
  #   class YourGem::BaseService < ActiveCall::Base
  #     ...
  #
  #     private
  #
  #     def not_found?
  #       response.status == 404 || (response.status == 400 && response.body['error_code'] == 'not_found')
  #     end
  #
  #     def unprocessable_entity?
  #       response.status == 422 || (response.status == 400 && response.body['error_code'] == 'not_processable')
  #     end
  #
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

  def not_implemented?
    response.status == 501
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
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path('api/locale/en.yml', __dir__)
end
