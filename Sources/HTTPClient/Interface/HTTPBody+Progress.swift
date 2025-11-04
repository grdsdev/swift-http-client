import Foundation

extension HTTPBody {
  /// Tracks the progress of the body and calls the handler.
  public func trackingProgress(handler: @escaping @Sendable (Progress) -> Void) -> HTTPBody {
    let totalLength: Int64? =
      switch self.length {
      case .known(let length):
        length
      case .unknown:
        nil
      }

    let sequence = ProgressTrackingSequence(
      base: self,
      totalLength: totalLength,
      handler: handler
    )

    return HTTPBody(sequence, length: self.length, iterationBehavior: self.iterationBehavior)
  }
}

/// An async sequence that tracks progress and forwards chunks from the underlying sequence.
private struct ProgressTrackingSequence: AsyncSequence, Sendable {
  typealias Element = HTTPBody.ByteChunk

  let base: HTTPBody
  let totalLength: Int64?
  let handler: @Sendable (Progress) -> Void

  func makeAsyncIterator() -> Iterator {
    Iterator(
      base: base.makeAsyncIterator(),
      totalLength: totalLength,
      handler: handler
    )
  }

  struct Iterator: AsyncIteratorProtocol {
    var base: HTTPBody.Iterator
    let totalLength: Int64?
    let handler: @Sendable (Progress) -> Void
    var totalBytesProcessed: Int64 = 0

    mutating func next() async throws -> Element? {
      guard let chunk = try await base.next() else {
        return nil
      }

      let chunkSize = Int64(chunk.count)
      totalBytesProcessed += chunkSize

      let progress = Progress(completed: totalBytesProcessed, total: totalLength)
      handler(progress)

      return chunk
    }
  }
}

/// A progress object that tracks the progress of a body.
public struct Progress: Sendable, Hashable {
  /// The number of bytes processed.
  public let completed: Int64
  /// The total number of bytes to process.
  public let total: Int64?

  /// The fraction of the body that has been processed.
  public var fractionCompleted: Double? {
    guard let total = total, total > 0 else { return nil }
    return Double(completed) / Double(total)
  }
}
