//
//  Client+MultipartFormData.swift
//  HTTPClient
//
//  Created by Guilherme Souza on 17/10/25.
//

import HTTPTypes

extension Client {

  public func send(
    multipartFormData: (MultipartFormData) -> Void,
    with request: HTTPRequest,
    usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let formData = MultipartFormData()
    multipartFormData(formData)
    return try await send(
      multipartFormData: formData,
      with: request,
      usingThreshold: encodingMemoryThreshold
    )
  }

  public func send(
    multipartFormData: MultipartFormData,
    with request: HTTPRequest,
    usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let requestBody = try multipartFormData.makeHTTPBody(threshold: encodingMemoryThreshold)
    var request = request
    request.headerFields[.contentType] = multipartFormData.contentType
    return try await send(request, body: requestBody)
  }
}
