import Foundation

public actor MockClientTransport: ClientTransport {

  public typealias RequestFilter = (HTTPRequest, HTTPBody?, URL) -> Bool

  struct Mock {
    let handleRequest: RequestFilter
    let returnResponse: () async throws -> (HTTPResponse, HTTPBody?)
  }

  public init() {}

  var mocks: [Mock] = []

  public func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL
  ) async throws -> (HTTPResponse, HTTPBody?) {
    for mock in mocks {
      if mock.handleRequest(request, body, baseURL) {
        return try await mock.returnResponse()
      }
    }
    throw MockNotFoundError(request: request, body: body, baseURL: baseURL)
  }

  @discardableResult
  public func on(
    _ request: @escaping RequestFilter,
    return response: @escaping () async throws -> (HTTPResponse, HTTPBody?)
  ) -> Self {
    let mock = Mock(handleRequest: request, returnResponse: response)
    mocks.append(mock)
    return self
  }

  @discardableResult
  public func on(
    _ request: @escaping (HTTPRequest) -> Bool,
    return response: @escaping () async throws -> (HTTPResponse, HTTPBody?)
  ) -> Self {
    self.on { r, _, _ in
      request(r)
    } return: {
      try await response()
    }

  }

  struct MockNotFoundError: Error {
    let request: HTTPRequest
    let body: HTTPBody?
    let baseURL: URL
  }
}

extension ClientTransport where Self == MockClientTransport {
  public static func mock() -> Self {
    MockClientTransport()
  }
}
