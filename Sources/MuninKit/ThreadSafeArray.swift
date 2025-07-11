import Foundation

/// A thread-safe array wrapper for concurrent append operations
final class ThreadSafeArray<Element: Sendable>: @unchecked Sendable {
    private var array: [Element] = []
    private let queue = DispatchQueue(label: "ThreadSafeArray", attributes: .concurrent)
    
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
    
    func updateElement(at index: Int, with updater: (inout Element) -> Void) {
        queue.sync(flags: .barrier) {
            guard index < self.array.count else { return }
            updater(&self.array[index])
        }
    }
    
    var all: [Element] {
        queue.sync { array }
    }
    
    var count: Int {
        queue.sync { array.count }
    }
}

/// A thread-safe set wrapper for concurrent insert operations
final class ThreadSafeSet<Element: Hashable & Sendable>: @unchecked Sendable {
    private var set: Set<Element> = []
    private let queue = DispatchQueue(label: "ThreadSafeSet", attributes: .concurrent)
    
    func insert(_ element: Element) {
        queue.sync(flags: .barrier) {
            self.set.insert(element)
        }
    }
    
    func formUnion(_ other: Set<Element>) {
        queue.sync(flags: .barrier) {
            self.set.formUnion(other)
        }
    }
    
    var all: Set<Element> {
        queue.sync { set }
    }
    
    var count: Int {
        queue.sync { set.count }
    }
}