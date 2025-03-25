# frozen_string_literal: true

require 'spec_helper'

class TestService < ActiveCall::Base
  include ActiveCall::Api

  attr_reader :id, :name

  validates :id, :name, presence: true

  def initialize(id: nil, name: nil, test_response: Faraday::Response.new(status: 200, body: { message: 'OK' }))
    @id = id
    @name = name
    @test_response = test_response
  end

  def call
    @test_response
  end

  def connection
    @_connection ||= Faraday.new do |conn|
      conn.adapter :test
    end
  end
end

class CustomMappingService < TestService
  class CustomValidationError < StandardError
    attr_reader :errors

    def initialize(errors, message = nil)
      @errors = errors
      super(message || errors.full_messages.join(', '))
    end
  end

  class CustomRequestError < StandardError
    attr_reader :response, :errors

    def initialize(response, errors, message = nil)
      @response = response
      @errors = errors
      super(message || errors.full_messages.join(', '))
    end
  end

  class << self
    def exception_mapping
      {
        validation_error: CustomValidationError,
        request_error:    CustomRequestError
      }
    end
  end
end

class NoConnectionService < ActiveCall::Base
  include ActiveCall::Api

  def call
    # Do nothing
  end
end

RSpec.describe ActiveCall::Api do
  it 'has a version number' do
    expect(ActiveCall::Api::VERSION).not_to be_nil
  end

  describe '.call' do
    context 'with valid params' do
      it 'returns a successful service instance' do
        service = TestService.call(id: 1, name: 'Test')
        expect(service).to be_success
        expect(service.errors).to be_empty
        expect(service.response.status).to eq(200)
      end
    end

    context 'with invalid params' do
      it 'returns an unsuccessful service instance with errors' do
        service = TestService.call(id: nil, name: nil)
        expect(service).not_to be_success
        expect(service.errors).not_to be_empty
        expect(service.errors.details[:id]).to include(error: :blank)
        expect(service.errors.details[:name]).to include(error: :blank)
      end
    end

    context 'with request errors' do
      it 'handles 4xx client errors' do
        test_response = Faraday::Response.new(status: 400, body: { message: 'Bad Request' })
        result = TestService.call(id: 1, name: 'Test', test_response: test_response)

        expect(result).not_to be_success
        expect(result.errors.details[:base]).to include(error: :bad_request)
      end

      it 'handles 5xx server errors' do
        test_response = Faraday::Response.new(status: 500, body: { message: 'Internal Server Error' })
        result = TestService.call(id: 1, name: 'Test', test_response: test_response)

        expect(result).not_to be_success
        expect(result.errors.details[:base]).to include(error: :internal_server_error)
      end
    end
  end

  describe '.call!' do
    context 'with valid params' do
      it 'returns a successful service instance' do
        service = TestService.call!(id: 1, name: 'Test')
        expect(service).to be_success
        expect(service.errors).to be_empty
        expect(service.response.status).to eq(200)
      end
    end

    context 'with invalid params' do
      it 'raises ValidationError' do
        expect { TestService.call!(id: nil, name: nil) }.to raise_error(ActiveCall::ValidationError) do |error|
          expect(error.errors.details[:id]).to include(error: :blank)
          expect(error.errors.details[:name]).to include(error: :blank)
        end
      end
    end

    context 'with request errors' do
      it 'raises appropriate error for 400 status' do
        test_response = Faraday::Response.new(status: 400, body: { message: 'Bad Request' })
        expect { TestService.call!(id: 1, name: 'Test', test_response: test_response) }.to raise_error(ActiveCall::BadRequestError) do |error|
          expect(error.response.status).to eq(400)
        end
      end

      it 'raises appropriate error for 404 status' do
        test_response = Faraday::Response.new(status: 404, body: { message: 'Not Found' })
        expect { TestService.call!(id: 1, name: 'Test', test_response: test_response) }.to raise_error(ActiveCall::NotFoundError) do |error|
          expect(error.response.status).to eq(404)
        end
      end

      it 'raises appropriate error for 500 status' do
        test_response = Faraday::Response.new(status: 500, body: { message: 'Server Error' })
        expect { TestService.call!(id: 1, name: 'Test', test_response: test_response) }.to raise_error(ActiveCall::InternalServerError) do |error|
          expect(error.response.status).to eq(500)
        end
      end
    end
  end

  describe 'custom exception mapping' do
    it 'uses custom exception classes when provided' do
      expect do
        CustomMappingService.call!(id: nil, name: nil)
      end.to raise_error(CustomMappingService::CustomValidationError)

      expect do
        test_response = Faraday::Response.new(status: 400, body: { message: 'Bad Request' })
        CustomMappingService.call!(id: 1, name: 'Test', test_response: test_response)
      end.to raise_error(CustomMappingService::CustomRequestError)
    end
  end

  describe '#connection' do
    it 'raises NotImplementedError when not defined' do
      service = NoConnectionService.new
      expect { service.connection }.to raise_error(NotImplementedError, /Subclasses must implement a connection method/)
    end
  end

  describe 'error detection methods' do
    let(:service) { TestService.new(id: 1, name: 'Test') }

    describe '#bad_request?' do
      it 'returns true for 400 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 400))
        expect(service.send(:bad_request?)).to be true
      end
    end

    describe '#unauthorized?' do
      it 'returns true for 401 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 401))
        expect(service.send(:unauthorized?)).to be true
      end
    end

    describe '#forbidden?' do
      it 'returns true for 403 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 403))
        expect(service.send(:forbidden?)).to be true
      end
    end

    describe '#not_found?' do
      it 'returns true for 404 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 404))
        expect(service.send(:not_found?)).to be true
      end
    end

    describe '#unprocessable_entity?' do
      it 'returns true for 422 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 422))
        expect(service.send(:unprocessable_entity?)).to be true
      end
    end

    describe '#internal_server_error?' do
      it 'returns true for 500 status' do
        service.instance_variable_set(:@response, Faraday::Response.new(status: 500))
        expect(service.send(:internal_server_error?)).to be true
      end
    end
  end

  describe 'exception_for method' do
    it 'returns the correct exception class based on error type' do
      response = Faraday::Response.new(status: 404)
      errors = ActiveModel::Errors.new(TestService.new)
      errors.add(:base, :not_found)

      exception = TestService.exception_for(response, errors)

      expect(exception).to be_a(ActiveCall::NotFoundError)
      expect(exception.response).to eq(response)
      expect(exception.errors).to eq(errors)
    end

    it 'falls back to RequestError for unknown error types' do
      response = Faraday::Response.new(status: 418) # I'm a teapot
      errors = ActiveModel::Errors.new(TestService.new)
      errors.add(:base, :teapot) # Not in mapping

      exception = TestService.exception_for(response, errors)

      expect(exception).to be_a(ActiveCall::RequestError)
    end
  end
end
