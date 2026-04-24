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

/// `ActivityIndicatorType` that renders a running count + current item.
/// Drives `ReadingProgress` through ConsoleKit's `ActivityIndicator<_>`
/// so both read and write paths share the same rendering, ephemeral-line
/// handling, and non-TTY graceful degradation.
struct ReadingActivity: ActivityIndicatorType {
  var title: String
  var count: Int = 0
  var text: String = ""

  func outputActivityIndicator(to console: any Console, state: ActivityIndicatorState) {
    switch state {
    case .ready:
      console.output(title.consoleText(.info))
    case .active:
      console.output("Found: [\(count)] \(text)".consoleText(.plain))
    case .success:
      console.output("Found: [\(count)]".consoleText(.success))
    case .failure:
      console.output("Read failed after \(count)".consoleText(.error))
    }
  }
}

/// Indeterminate progress display (running count + current item) used during
/// input scanning. Wraps ``ReadingActivity`` in ConsoleKit's generic
/// `ActivityIndicator` so the refresh loop, ANSI handling, and TTY fallback
/// match ``WritingProgress``.
public final class ReadingProgress {
  private let indicator: ActivityIndicator<ReadingActivity>
  private var started = false
  private let lock = NSLock()

  public init(terminal: Terminal = Terminal(), header: String) {
    self.indicator = ReadingActivity(title: header).newActivity(for: terminal)
  }

  /// Update the display with the current count and current item name.
  public func update(count: Int, text: String) {
    lock.lock()
    defer { lock.unlock() }
    if !started {
      indicator.start()
      started = true
    }
    var snapshot = indicator.activity
    snapshot.count = count
    snapshot.text = text
    indicator.activity = snapshot
  }

  /// Finalize the display. Safe to call multiple times.
  public func complete() {
    lock.lock()
    defer { lock.unlock() }
    guard started else { return }
    indicator.succeed()
    started = false
  }
}
