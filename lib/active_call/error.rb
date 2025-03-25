# frozen_string_literal: true

module ActiveCall
  # 400..499
  class ClientError < RequestError; end

  # 400
  class BadRequestError < ClientError; end

  # 401
  class UnauthorizedError < ClientError; end

  # 403
  class ForbiddenError < ClientError; end

  # 404
  class NotFoundError < ClientError; end

  # 406
  class NotAcceptableError < ClientError; end

  # 407
  class ProxyAuthenticationRequiredError < ClientError; end

  # 408
  class RequestTimeoutError < ClientError; end

  # 409
  class ConflictError < ClientError; end

  # 422
  class UnprocessableEntityError < ClientError; end

  # 429
  class TooManyRequestsError < ClientError; end

  # 500..599
  class ServerError < RequestError; end

  # 500
  class InternalServerError < ServerError; end

  # 501
  class NotImplementedError < ServerError; end

  # 502
  class BadGatewayError < ServerError; end

  # 503
  class ServiceUnavailableError < ServerError; end

  # 504
  class GatewayTimeoutError < ServerError; end
end
