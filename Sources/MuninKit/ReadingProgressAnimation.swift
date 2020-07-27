import Foundation
import TSCBasic
import TSCUtility

public final class ReadingProgressAnimation: ProgressAnimationProtocol {
  private let terminal: TerminalController
  private let header: String
  private var hasDisplayedHeader = false

  init(terminal: TerminalController, header: String) {
    self.terminal = terminal
    self.header = header
  }

  /// Creates repeating string for count times.
  /// If count is negative, returns empty string.
  private func repeating(string: String, count: Int) -> String {
    return String(repeating: string, count: max(count, 0))
  }

  private func writeLong(_ text: String) {
    if text.utf8.count > terminal.width {
      let suffix = "…"
      terminal.write(String(text.prefix(terminal.width - suffix.utf8.count)))
      terminal.write(suffix)
    } else {
      terminal.write(text)
    }
  }

  public func update(step: Int, total: Int, text: String) {
    if !hasDisplayedHeader {
      let spaceCount = terminal.width / 2 - header.utf8.count / 2
      terminal.write(repeating(string: " ", count: spaceCount))
      terminal.write(header, inColor: .cyan, bold: true)
      terminal.endLine()
      hasDisplayedHeader = true
    }

    terminal.clearLine()
    terminal.write("Found: ", inColor: .cyan, bold: true)
    terminal.write("[", inColor: .green, bold: true)
    terminal.write(String(step), inColor: .white)
    terminal.write("]", inColor: .green, bold: true)
    terminal.endLine()
    terminal.clearLine()
    writeLong(text)
    terminal.moveCursor(up: 1)
  }

  public func complete(success: Bool) {
    terminal.endLine()
    terminal.endLine()
    terminal.endLine()
  }

  public func clear() {
    terminal.clearLine()
    terminal.moveCursor(up: 1)
    terminal.clearLine()
  }

}
