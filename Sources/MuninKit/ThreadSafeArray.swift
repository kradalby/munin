import Foundation

/// A thread-safe array wrapper for concurrent append operations.
///
/// Introduced in the Swift 6.3 toolchain bump as a minimum-viable replacement
/// for the previous `var photos = [Photo]()` captured-by-reference pattern,
/// which violates Swift 6's strict concurrency rules.
///
/// **Temporary.** This type is scheduled for removal once the GCD-based
/// read/write pipelines in `Album.swift` are converted to structured
/// concurrency using `TaskGroup`. Tracked by MUNIN_MODERNISE_PLAN.md
/// commits 10–12.
final class ThreadSafeArray<Element: Sendable>: @unchecked Sendable {
  private var array: [Element] = []
  private let queue = DispatchQueue(
    label: "no.kradalby.MuninKit.ThreadSafeArray",
    attributes: .concurrent)

  func append(_ element: Element) {
    queue.sync(flags: .barrier) {
      self.array.append(element)
    }
  }

  func sort(by areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
    queue.sync(flags: .barrier) {
      self.array.sort(by: areInIncreasingOrder)
    }
  }

  var all: [Element] {
    queue.sync { array }
  }

  var count: Int {
    queue.sync { array.count }
  }
}
