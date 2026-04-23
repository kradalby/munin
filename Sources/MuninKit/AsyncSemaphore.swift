import Foundation

/// Actor-based counting semaphore for bounding concurrency in `async` code.
///
/// `AsyncSemaphore` is a direct replacement for `DispatchSemaphore` in async
/// contexts. Unlike a `DispatchSemaphore`, calling `wait()` suspends the
/// current `Task` instead of blocking a thread, so it composes cleanly with
/// structured concurrency (`TaskGroup`, `async let`, etc.).
///
/// Usage:
/// ```swift
/// let sem = AsyncSemaphore(value: 4)
/// await withThrowingTaskGroup(of: Result.self) { group in
///   for item in items {
///     await sem.wait()
///     group.addTask {
///       defer { Task { await sem.signal() } }
///       return try process(item)
///     }
///   }
///   ...
/// }
/// ```
///
/// The implementation uses a list of suspended continuations as the wait
/// queue. `signal()` either decrements the pending-wait count (freeing a
/// slot) or resumes the oldest waiter, preserving FIFO fairness.
public actor AsyncSemaphore {
  private var value: Int
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// Creates a new semaphore with the given number of permits.
  ///
  /// - Parameter value: The initial permit count. Must be non-negative.
  public init(value: Int) {
    precondition(value >= 0, "AsyncSemaphore initial value must be non-negative")
    self.value = value
  }

  /// Acquires a permit, suspending the caller until one is available.
  public func wait() async {
    if value > 0 {
      value -= 1
      return
    }
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  /// Releases a permit. If a task is waiting, it is resumed.
  public func signal() {
    if let next = waiters.first {
      waiters.removeFirst()
      next.resume()
    } else {
      value += 1
    }
  }

  /// Current number of waiters suspended on this semaphore. Primarily for
  /// testing; production code should not rely on this.
  internal var pendingWaiters: Int {
    waiters.count
  }

  /// Current permit count. Primarily for testing.
  internal var availablePermits: Int {
    value
  }
}
