import Foundation
import Testing

@testable import MuninKit

/// Locks the Imaging facade boundary: swift-vips and SwiftExif must only
/// be imported from the two files in `Sources/MuninKit/IO/Imaging/` plus
/// the `VIPSBootstrap` lifecycle layer. Any drift — e.g. a refactor that
/// inlines a `VIPSImage` use back into `Photo+Write` — fails this test
/// loudly.
///
/// This is a static-text audit, not a concurrency test; keeping it in
/// the suite means CI refuses a merge that punches through the boundary.
@Suite
struct ImagingFacadeTests {

  /// Library files allowed to reference swift-vips / SwiftExif directly.
  /// Anything else importing those modules is a boundary violation.
  private static let allowedFiles: Set<String> = [
    "Sources/MuninKit/IO/Imaging/VIPS.swift",
    "Sources/MuninKit/IO/Imaging/EXIF.swift",
    "Sources/MuninKit/VIPSBootstrap.swift",
  ]

  @Test func onlyFacadeFilesImportVIPSOrSwiftExif() throws {
    let sourcesRoot = FileManager.default.currentDirectoryPath + "/Sources/MuninKit"
    let offenders = try filesImporting(
      modules: ["VIPS", "SwiftExif", "Cvips"],
      under: sourcesRoot)

    let cwd = FileManager.default.currentDirectoryPath + "/"
    let relative = offenders.map { $0.hasPrefix(cwd) ? String($0.dropFirst(cwd.count)) : $0 }
    let unexpected = relative.filter { !Self.allowedFiles.contains($0) }

    #expect(
      unexpected.isEmpty,
      "swift-vips / SwiftExif imports outside the Imaging facade: \(unexpected)")
  }

  /// Walk `root` and return every `.swift` file that contains a top-level
  /// `import <module>` line for one of `modules`.
  private func filesImporting(modules: [String], under root: String) throws -> [String] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: root) else { return [] }

    var matches: [String] = []
    let patterns = modules.map { "import \($0)" }

    while let relative = enumerator.nextObject() as? String {
      guard relative.hasSuffix(".swift") else { continue }
      let full = root + "/" + relative
      guard let contents = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
      for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if patterns.contains(where: { trimmed == $0 }) {
          matches.append(full)
          break
        }
      }
    }
    return matches
  }
}
