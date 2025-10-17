import Foundation

extension HTTPBody {
  /// Tracks the progress of the body and calls the handler.
  public func trackingProgress(handler: @escaping (Progress) -> Void) -> HTTPBody {
    var totalBytesProcessed: Int64 = 0
    let totalLength: Int64? =
      switch self.length {
      case .known(let length):
        length
      case .unknown:
        nil
      }

    let sequence = self.map { chunk in
      let chunkSize = Int64(chunk.count)
      totalBytesProcessed += chunkSize

      let progress = Progress(completed: totalBytesProcessed, total: totalLength)
      handler(progress)
      return chunk
    }

    return HTTPBody(sequence, length: self.length, iterationBehavior: self.iterationBehavior)
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
