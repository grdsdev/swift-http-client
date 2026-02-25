import Foundation

/// A thread-safe box for collecting values from @Sendable closures in tests.
///
/// This type wraps a mutable value with an `NSLock` to allow safe mutation
/// from `@Sendable` closures, which is commonly needed in tests that capture
/// state from transport or middleware callbacks.
final class SendableBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(_ value: T) {
    self._value = value
  }

  var value: T {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func withLock<R>(_ body: (inout T) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return body(&_value)
  }
}
