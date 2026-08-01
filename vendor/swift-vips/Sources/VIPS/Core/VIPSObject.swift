import Cvips
import CvipsShim

final class ClosureHolder<Input, Output> where Input: ~Copyable, Input: ~Escapable, Output: ~Copyable, Output: ~Escapable {
    let closure: (borrowing Input) -> Output

    init(_ closure: @escaping (borrowing Input) -> Output) {
        self.closure = closure
    }
}

open class VIPSObject: VIPSObjectProtocol {
    public required init(_ ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }

    public var ptr: UnsafeMutableRawPointer!

    @usableFromInline
    init(_ object: UnsafeMutablePointer<VipsObject>) {
        self.ptr = UnsafeMutableRawPointer(object)
    }

    public var type: GType {
        return shim_g_object_type(object)
    }

    public func withVipsObject<R>(_ body: (UnsafeMutablePointer<VipsObject>) throws -> R) rethrows
        -> R
    {
        return try body(self.object)
    }

    deinit {
        guard let ptr = self.ptr else { return }
        g_object_unref(ptr)
        self.ptr = nil
    }
}

public protocol PointerWrapper: ~Copyable, ~Escapable {
    init(_ ptr: UnsafeMutableRawPointer)
    var ptr: UnsafeMutableRawPointer! { get }
}

public protocol VIPSObjectProtocol: PointerWrapper, ~Copyable, ~Escapable {
    var object: UnsafeMutablePointer<VipsObject>! { get }
}

extension VIPSObjectProtocol where Self : ~Copyable, Self: ~Escapable {
    public var object: UnsafeMutablePointer<VipsObject>! {
        return self.ptr.assumingMemoryBound(to: VipsObject.self)
    }

    public var type: GType {
        return shim_g_object_type(object)
    }

    public func withVipsObject<R>(_ body: (UnsafeMutablePointer<VipsObject>) throws -> R) rethrows
        -> R
    {
        return try body(self.object)
    }

    @discardableResult
    public func onPreClose(_ handler: @escaping (UnownedVIPSObjectRef) -> Void) -> Int {
        let closureHolder = ClosureHolder(handler)
        let gpointer = Unmanaged.passRetained(closureHolder).toOpaque()

        let callback: @convention(c) (UnsafeMutablePointer<VipsObject>?, gpointer?) -> Void = {
            (
                objectPtr: UnsafeMutablePointer<VipsObject>?,
                userData: gpointer?
            ) -> Void in
            guard
                let objectPtr = objectPtr,
                let userData
            else {
                return
            }

            let closureHolder = Unmanaged<
                ClosureHolder<(UnownedVIPSObjectRef), Void>
            >
            .fromOpaque(userData).takeUnretainedValue()

            closureHolder.closure((UnownedVIPSObjectRef(objectPtr)))
        }

        return self.connect(
            signal: "preclose",
            callback: unsafeBitCast(callback, to: GCallback.self),
            userData: gpointer,
            destroyData: { userData, _ in
                if let userData {
                    Unmanaged<
                        ClosureHolder<(VIPSObjectRef), Void>
                    >
                    .fromOpaque(userData).release()
                    print("ClosureHolder released")
                }
            },
            flags: .default
        )
    }

    @discardableResult
    public func connect(
        signal: String,
        callback: GCallback,
        userData: gpointer?,
        destroyData: GClosureNotify?,
        flags: GConnectFlags = .default
    ) -> Int {
        return Int(
            g_signal_connect_data(
                self.object,
                signal,
                callback,
                userData,
                destroyData,
                flags
            )
        )
    }

    public func disconnect(signalHandler: Int) {
        g_signal_handler_disconnect(self.ptr, gulong(signalHandler))
    }
}

public struct VIPSObjectRef: VIPSObjectProtocol, ~Copyable {
    public let ptr: UnsafeMutableRawPointer!

    public init(_ ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }

    public init(borrowing ref: UnownedVIPSObjectRef) {
        self.ptr = ref.ptr
        g_object_ref(ref.ptr)
    }

    deinit {
        g_object_unref(self.ptr)
    }
}

public struct UnownedVIPSObjectRef: VIPSObjectProtocol, ~Escapable {
    public let ptr: UnsafeMutableRawPointer!

    public init(_ ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }
}