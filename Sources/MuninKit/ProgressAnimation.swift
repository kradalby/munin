import ConsoleKitTerminal
import Foundation

/// Determinate progress display (percentage-based) used when writing images.
///
/// Backed by ConsoleKit's `ProgressBar`, which handles background rendering
/// and gracefully degrades when stdout is not a TTY.
public final class WritingProgress {
  private let indicator: ActivityIndicator<ProgressBar>
  private var started = false
  private let lock = NSLock()

  public init(terminal: Terminal = Terminal(), title: String) {
    self.indicator = terminal.progressBar(title: title)
  }

  /// Update the bar with the current step/total and ensure it is started.
  public func update(step: Int, total: Int) {
    lock.lock()
    defer { lock.unlock() }
    if !started {
      indicator.start()
      started = true
    }
    guard total > 0 else { return }
    let fraction = min(max(Double(step) / Double(total), 0.0), 1.0)
    indicator.activity.currentProgress = fraction
  }

  /// Finish the bar. Safe to call multiple times.
  public func complete(success: Bool = true) {
    lock.lock()
    defer { lock.unlock() }
    guard started else { return }
    if success {
      indicator.succeed()
    } else {
      indicator.fail()
    }
    started = false
  }
}

/// Indeterminate progress display (running count + current item) used during
/// input scanning.
///
/// Minimal in-tree implementation: prints a colored header on first use, then
/// repeatedly clears the line and re-emits the current count and item text.
/// Silent when stdout is not a TTY.
public final class ReadingProgress {
  private let out: FileHandle
  private let header: String
  private let isInteractive: Bool
  private var hasDisplayedHeader = false
  private let lock = NSLock()

  public init(fileHandle: FileHandle = .standardOutput, header: String) {
    self.out = fileHandle
    self.header = header
    self.isInteractive = isatty(fileHandle.fileDescriptor) != 0
  }

  /// Update the display with the current count and current item name.
  public func update(count: Int, text: String) {
    guard isInteractive else { return }
    lock.lock()
    defer { lock.unlock() }
    if !hasDisplayedHeader {
      write("\u{1B}[1;36m\(header)\u{1B}[0m\n")
      hasDisplayedHeader = true
    }
    // CR + clear line + re-emit
    write("\r\u{1B}[2KFound: [\(count)] \(text)")
  }

  /// Finalize the display (terminates the in-progress line).
  public func complete() {
    guard isInteractive else { return }
    lock.lock()
    defer { lock.unlock() }
    write("\n")
  }

  private func write(_ s: String) {
    out.write(Data(s.utf8))
  }
}
