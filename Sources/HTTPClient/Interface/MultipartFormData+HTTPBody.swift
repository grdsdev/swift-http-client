import Foundation
import HTTPTypes

extension MultipartFormData {
  /// Creates an HTTPBody from the multipart form data.
  ///
  /// This method automatically chooses between in-memory and disk-based encoding
  /// based on the content length and the provided threshold.
  ///
  /// - Parameter threshold: The maximum size (in bytes) for in-memory encoding.
  ///   Defaults to `MultipartFormData.encodingMemoryThreshold` (10 MB).
  ///   If the content length exceeds this threshold, disk-based encoding is used.
  /// - Returns: An HTTPBody containing the encoded multipart form data.
  /// - Throws: An `EncodingError` if encoding fails.
  func makeHTTPBody(
    threshold: UInt64 = MultipartFormData.encodingMemoryThreshold
  ) throws -> HTTPBody {
    let contentLength = self.contentLength

    if contentLength <= threshold {
      // In-memory encoding for smaller payloads
      let data = try encode()
      return HTTPBody(data)
    } else {
      // Disk-based encoding for larger payloads
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("multipart")

      try writeEncodedData(to: tempURL)

      // Create a streaming body from the file
      return try HTTPBody(
        streamingFromFile: tempURL,
        deleteOnDeallocation: true
      )
    }
  }
}

extension HTTPBody {
  /// Creates an HTTPBody that streams data from a file.
  ///
  /// - Parameters:
  ///   - fileURL: The URL of the file to stream.
  ///   - deleteOnDeallocation: Whether to delete the file when the body is deallocated.
  /// - Throws: An error if the file cannot be accessed.
  convenience init(streamingFromFile fileURL: URL, deleteOnDeallocation: Bool = false)
    throws
  {
    guard fileURL.isFileURL else {
      throw MultipartFormData.EncodingError(reason: .bodyPartURLInvalid(url: fileURL))
    }

    let fileSize =
      try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber
    let length = fileSize?.uint64Value

    let fileHandle = try FileHandle(forReadingFrom: fileURL)

    let stream = AsyncThrowingStream<ByteChunk, any Error> { continuation in
      continuation.onTermination = { _ in
        try? fileHandle.close()
        if deleteOnDeallocation {
          try? FileManager.default.removeItem(at: fileURL)
        }
      }

      do {
        while true {
          let bytes = fileHandle.readData(ofLength: 64 * 1024)  // 64 KB chunks
          if bytes.isEmpty {
            break
          }
          continuation.yield(ByteChunk(bytes))
        }
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }

    self.init(stream, length: length.map { .known(Int64($0)) } ?? .unknown)
  }
}
