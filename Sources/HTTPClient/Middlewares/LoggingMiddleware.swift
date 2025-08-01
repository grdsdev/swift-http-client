import Logging

#if canImport(Darwin)
  import struct Foundation.URL
  import struct Foundation.UUID
#else
  @preconcurrency import struct Foundation.URL
  @preconcurrency import struct Foundation.UUID
#endif

public struct LoggingMiddleware: ClientMiddleware {
  let logger: Logger
  let includeMetadata: Bool

  public init(logger: Logger, includeMetadata: Bool = true) {
    self.logger = logger
    self.includeMetadata = includeMetadata
  }

  public func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var logger = logger
    if includeMetadata, logger[metadataKey: "request-id"] == nil {
      logger[metadataKey: "request-id"] = .string(UUID().uuidString)
    }
    logger.trace("⬆️ \(request.prettyDescription)")
    let (response, body) = try await next(request, body, baseURL)
    logger.trace("⬇️ \(response.prettyDescription)")
    return (response, body)
  }
}
