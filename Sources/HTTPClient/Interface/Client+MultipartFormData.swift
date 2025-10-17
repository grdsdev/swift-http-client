//
//  Client+MultipartFormData.swift
//  HTTPClient
//
//  Created by Guilherme Souza on 17/10/25.
//

import HTTPTypes

extension Client {

  /// Sends an HTTP request with `multipart/form-data`.
  ///
  /// - Parameters:
  ///   - multipartFormData: A closure that receives a `MultipartFormData` instance for configuration.
  ///     Use the methods on `MultipartFormData` to append data, files, or streams to the request body.
  ///   - request: The HTTP request to send. The `Content-Type` header will be automatically set
  ///     to `multipart/form-data; boundary=<generated-boundary>`.
  ///   - encodingMemoryThreshold: The size threshold, in bytes, that determines whether the multipart
  ///     form data should be encoded in memory or written to disk. Defaults to 10 MB. If the total
  ///     size of the multipart data exceeds this threshold, it will be written to a temporary file
  ///     and streamed; otherwise, it will be encoded directly in memory.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let request = HTTPRequest(method: .post, url: URL(string: "/api/upload")!)
  ///
  /// let (response, body) = try await client.send(
  ///     multipartFormData: { formData in
  ///         // Add a text field
  ///         formData.append(
  ///             "John Doe".data(using: .utf8)!,
  ///             withName: "username"
  ///         )
  ///
  ///         // Add a file
  ///         let fileURL = URL(fileURLWithPath: "/path/to/document.pdf")
  ///         formData.append(fileURL, withName: "document")
  ///
  ///         // Add image data with custom filename and MIME type
  ///         let imageData = ... // Your image data
  ///         formData.append(
  ///             imageData,
  ///             withName: "photo",
  ///             fileName: "selfie.jpg",
  ///             mimeType: "image/jpeg"
  ///         )
  ///     },
  ///     with: request
  /// )
  ///
  /// if response.status == .ok {
  ///     print("Upload successful!")
  /// }
  /// ```
  ///
  /// - SeeAlso: ``MultipartFormData``
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

  /// Sends an HTTP request with `multipart/form-data`.
  ///
  /// - Parameters:
  ///   - multipartFormData: A configured `MultipartFormData` instance containing the data to send.
  ///     This instance should have body parts already appended to it using methods like
  ///     `append(_:withName:)`, `append(_:withName:fileName:mimeType:)`, etc.
  ///   - request: The HTTP request to send. The `Content-Type` header will be automatically set
  ///     to `multipart/form-data; boundary=<boundary-from-formData>`.
  ///   - encodingMemoryThreshold: The size threshold, in bytes, that determines whether the multipart
  ///     form data should be encoded in memory or written to disk. Defaults to 10 MB. If the total
  ///     size of the multipart data exceeds this threshold, it will be written to a temporary file
  ///     and streamed; otherwise, it will be encoded directly in memory.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Create and configure multipart form data
  /// let formData = MultipartFormData()
  ///
  /// // Add a text field
  /// formData.append(
  ///     "premium".data(using: .utf8)!,
  ///     withName: "subscription_type"
  /// )
  ///
  /// // Add a video file (larger data that will likely be streamed)
  /// let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
  /// formData.append(
  ///     videoURL,
  ///     withName: "video",
  ///     fileName: "presentation.mp4",
  ///     mimeType: "video/mp4"
  /// )
  ///
  /// // Send the request
  /// let request = HTTPRequest(method: .post, url: URL(string: "/api/videos")!)
  /// let (response, body) = try await client.send(
  ///     multipartFormData: formData,
  ///     with: request,
  ///     usingThreshold: 20_000_000  // 20 MB threshold
  /// )
  ///
  /// if response.status == .created {
  ///     print("Video uploaded successfully!")
  /// }
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// When uploading large files (such as videos), consider:
  /// - Increasing the `encodingMemoryThreshold` to match your expected file sizes
  /// - Using a threshold that balances memory usage with performance
  /// - For very large files (>100 MB), the default threshold ensures streaming behavior
  ///
  /// - SeeAlso: ``MultipartFormData``
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
