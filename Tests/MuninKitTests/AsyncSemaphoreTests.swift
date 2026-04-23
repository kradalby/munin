import Foundation
import XCTest

@testable import MuninKit

final class AsyncSemaphoreTests: XCTestCase {

  func testImmediateAcquireWhenPermitsAvailable() async {
    let sem = AsyncSemaphore(value: 2)
    await sem.wait()
    await sem.wait()
    let permits = await sem.availablePermits
    XCTAssertEqual(permits, 0)
  }

  func testWaitSuspendsWhenNoPermits() async {
    let sem = AsyncSemaphore(value: 0)
    // Kick off a task that will suspend on wait().
    let waiter = Task {
      await sem.wait()
      return "done"
    }

    // Give the task time to suspend.
    try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
    let waiters = await sem.pendingWaiters
    XCTAssertEqual(waiters, 1)

    // Signal releases it.
    await sem.signal()
    let result = await waiter.value
    XCTAssertEqual(result, "done")
  }

  func testSignalWithoutWaiterIncrementsPermits() async {
    let sem = AsyncSemaphore(value: 0)
    await sem.signal()
    let permits = await sem.availablePermits
    XCTAssertEqual(permits, 1)
  }

  func testFIFOOrdering() async {
    let sem = AsyncSemaphore(value: 0)

    // Start 3 tasks that wait in order, each yielding their index on completion.
    async let first: Int = {
      await sem.wait()
      return 1
    }()
    try? await Task.sleep(nanoseconds: 5_000_000)
    async let second: Int = {
      await sem.wait()
      return 2
    }()
    try? await Task.sleep(nanoseconds: 5_000_000)
    async let third: Int = {
      await sem.wait()
      return 3
    }()
    try? await Task.sleep(nanoseconds: 5_000_000)

    // Release them one at a time; collect results in resume order.
    await sem.signal()
    let a = await first
    await sem.signal()
    let b = await second
    await sem.signal()
    let c = await third

    XCTAssertEqual([a, b, c], [1, 2, 3])
  }

  func testBoundsConcurrentWork() async {
    let sem = AsyncSemaphore(value: 3)
    let concurrent = ConcurrencyCounter()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<20 {
        group.addTask {
          await sem.wait()
          await concurrent.incrementAndTrack()
          try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms work
          await concurrent.decrement()
          await sem.signal()
        }
      }
    }

    let maxSeen = await concurrent.peak
    XCTAssertLessThanOrEqual(maxSeen, 3, "Semaphore should cap concurrency at 3")
  }

  private actor ConcurrencyCounter {
    private var current = 0
    private var peakValue = 0

    func incrementAndTrack() {
      current += 1
      peakValue = max(peakValue, current)
    }

    func decrement() {
      current -= 1
    }

    var peak: Int { peakValue }
  }
}
