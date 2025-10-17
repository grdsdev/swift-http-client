import Foundation

extension HTTPBody {
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

public struct Progress: Sendable, Hashable {
  public let completed: Int64
  public let total: Int64?

  public var fractionCompleted: Double? {
    guard let total = total, total > 0 else { return nil }
    return Double(completed) / Double(total)
  }
}
