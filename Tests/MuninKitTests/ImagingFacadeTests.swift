import Foundation
import Testing

@testable import MuninKit

/// Locks the Imaging facade boundary: libvips and SwiftExif must only be
/// imported from the files in `Sources/MuninKit/IO/Imaging/` plus the
/// `VIPSBootstrap` lifecycle layer. Any drift — e.g. a refactor that
/// inlines a `VIPSImage` use back into `Photo+Write` — fails this test
/// loudly.
///
/// Scanning imports is sufficient only because the binding is a module of
/// its own: `VIPSImage`, `VIPSError` and `VIPS` live in `MuninVips`, so a
/// MuninKit file that names one without importing it does not compile
/// ("cannot find 'VIPSImage' in scope"), and raw `vips_*` calls still need a
/// literal `import Cvips`. Every route to libvips therefore writes an import
/// line, and the scan below matches the real import grammar rather than one
/// exact spelling. Inline the binding back into MuninKit — where a type is
/// in scope with no import at all — and this test stops meaning anything.
///
/// This is a static-text audit, not a concurrency test; keeping it in
/// the suite means CI refuses a merge that punches through the boundary.
@Suite
struct ImagingFacadeTests {

  /// Library files allowed to reference libvips / SwiftExif directly.
  /// Anything else importing those modules is a boundary violation.
  private static let allowedFiles: Set<String> = [
    "Sources/MuninKit/IO/Imaging/VIPS.swift",
    "Sources/MuninKit/IO/Imaging/EXIF.swift",
    "Sources/MuninKit/VIPSBootstrap.swift",
  ]

  /// Targets that *are* the binding, and so are exempt from the scan.
  private static let bindingTargets = ["MuninVips", "Cvips", "MuninVipsShim"]

  @Test func onlyFacadeFilesImportVIPSOrSwiftExif() throws {
    // Rooted at Sources/, not Sources/MuninKit: `package` access spans the
    // whole package and SwiftPM makes the binding importable from the
    // executable target too, so scanning only MuninKit left a real route open.
    let sourcesRoot = FileManager.default.currentDirectoryPath + "/Sources"
    // Cvips and MuninVipsShim stay on the list even though MuninKit no
    // longer depends on them: SwiftPM makes a transitive C module importable
    // anyway, so dropping the target dependency alone does not close them.
    let offenders = try filesImporting(
      modules: ["MuninVips", "Cvips", "MuninVipsShim", "SwiftExif"],
      under: sourcesRoot)

    let cwd = FileManager.default.currentDirectoryPath + "/"
    let relative = offenders.map { $0.hasPrefix(cwd) ? String($0.dropFirst(cwd.count)) : $0 }
    let unexpected = relative.filter { !Self.allowedFiles.contains($0) }

    #expect(
      unexpected.isEmpty,
      "libvips / SwiftExif imports outside the Imaging facade: \(unexpected)")
  }

  /// True if `line` is an import declaration naming one of `modules`.
  ///
  /// Tokenised rather than compared whole, because `import class
  /// MuninVips.VIPSImage`, `@preconcurrency import MuninVips` and a leading
  /// indent are all real imports that an equality check walks straight past
  /// — and this test is only worth having if it cannot be sidestepped by
  /// spelling the import differently. Comments and string literals
  /// containing the word are excluded by requiring `import` to be the first
  /// token, or the second after an attribute.
  static func isImport(_ line: String, of modules: Set<String>) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.hasPrefix("//") else { return false }
    let tokens = trimmed
      .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
      .map(String.init)
    guard tokens.first == "import" || (tokens.count > 1 && tokens[1] == "import") else {
      return false
    }
    return tokens.contains(where: modules.contains)
  }

  /// Walk `root` and return every `.swift` file importing one of `modules`,
  /// skipping the binding targets themselves.
  private func filesImporting(modules: [String], under root: String) throws -> [String] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: root) else { return [] }
    let wanted = Set(modules)

    var matches: [String] = []
    while let relative = enumerator.nextObject() as? String {
      guard relative.hasSuffix(".swift") else { continue }
      guard !Self.bindingTargets.contains(where: { relative.hasPrefix($0 + "/") }) else { continue }
      let full = root + "/" + relative
      guard let contents = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
      for line in contents.split(separator: "\n", omittingEmptySubsequences: true)
      where Self.isImport(String(line), of: wanted) {
        matches.append(full)
        break
      }
    }
    return matches
  }

  /// The detector itself, pinned. Without this the boundary test can rot
  /// into a no-op that still passes — the failure mode this whole suite
  /// exists to prevent, one level up.
  @Test func importDetectorRecognisesEverySpelling() {
    let mods: Set<String> = ["MuninVips", "Cvips", "SwiftExif"]
    for line in [
      "import MuninVips", "  import Cvips", "@preconcurrency import MuninVips",
      "@testable import MuninVips", "import class MuninVips.VIPSImage",
      "import struct MuninVips.Foo", "import SwiftExif",
    ] {
      #expect(Self.isImport(line, of: mods), "missed a real import: \(line)")
    }
    for line in [
      "import MuninKit", "// import MuninVips", "  // import Cvips",
      "let x = \"import MuninVips\"", "", "func f() {}",
    ] {
      #expect(!Self.isImport(line, of: mods), "false positive: \(line)")
    }
  }
}
