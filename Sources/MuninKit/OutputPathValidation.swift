import Foundation
import SystemPackage

/// One output path that more than one source wants to write.
public struct OutputPathCollision: Sendable, Equatable {
  /// The output path both sources resolve to.
  public let outputPath: String

  /// Every source path claiming it, sorted. A source directory appears
  /// here when the album's own `index.json` is the contested path.
  public let sources: [String]
}

/// Verify that the map from source *path* to output path is injective,
/// and return every place it is not.
///
/// Munin derives output names from source names, and three of those
/// derivations lose information:
///
/// - a photo's metadata file is `<stem>.json`, with the source extension
///   dropped, so `sample.jpg` and `sample.jpeg` — both in the stock
///   `fileExtensions` — resolve to one `sample.json`;
/// - an album's folder is `urlifyName(name)`, which replaces spaces with
///   underscores, so sibling directories `My Album` and `My_Album`
///   resolve to one folder;
/// - a keyword page is `keywords/<urlifyName(keyword)>.json`, so the IPTC
///   keywords `Tel Aviv District` and `Tel_Aviv_District` resolve to one
///   file. That one is *not* checked here — keyword names come from EXIF,
///   which this walk deliberately does not read — but by
///   ``findKeywordOutputPathCollisions(album:)`` after the read.
///
/// Nothing else loses uniqueness: the symlinked original and every scaled
/// image keep the source extension (`sample_original.jpg`,
/// `sample_180.jpeg`), and filenames are unique within a directory by
/// filesystem law, so those names are already 1:1 with their source. The
/// `.json` namespace and the folder namespace are the whole surface of
/// *this* check, and they share one namespace per album directory — a
/// photo named `index.jpg` contends with the album's own listing, and a
/// directory named `x.json` contends with a photo named `x`.
///
/// One interaction neither check covers: a gallery whose name urlifies to
/// `keywords` puts its album tree in the same directory as the keyword
/// pages, so a root-level photo `x.jpg` and a keyword `x` would contend.
/// Filed with the other gallery-name pathologies in FUTURES.md item 14.
///
/// This walks names only: no EXIF, no VIPS, no hashing. It is cheap
/// enough to run before the read so a rejected build costs nothing and,
/// more importantly, leaves the previously-generated gallery untouched.
///
/// One consequence of running that early: a photo excluded from the
/// gallery by the `NO_HUGIN` keyword is still counted here, because
/// knowing it is excluded means reading its EXIF. So `a.jpg` plus a
/// `NO_HUGIN`-tagged `a.png` is rejected even though only one of them
/// would have been published. That is the deliberate trade — the
/// alternative is paying the full read before finding out, and such a
/// gallery is one untag away from silently losing a photo anyway.
func findOutputPathCollisions(ctx: Context) -> [OutputPathCollision] {
  var found: [OutputPathCollision] = []
  collectOutputPathCollisions(
    // Normalised the same way `readStateFromInputDirectory` normalises
    // its own `atPath`, so both walks see the same directory.
    sourcePath: joinPath(ctx.config.inputPath),
    outputPath: joinPath(ctx.config.outputPath, urlifyName(ctx.config.name)),
    isRoot: true,
    extensions: Set(ctx.config.fileExtensions),
    into: &found)
  return found.sorted { canonicalThenBytewiseLess($0.outputPath, $1.outputPath) }
}

/// The third information-losing derivation: `keywords/<urlified>.json`,
/// which `buildKeywordsFromAlbum` and `buildPeopleFromAlbum` both write
/// into one directory. Returns every page more than one keyword claims.
///
/// Two keyword names that urlify to the same file (`Tel Aviv District`
/// and `Tel_Aviv_District`) share one page, and the loser's photos link to
/// a page that does not contain them. Both buckets are collected because
/// they write into one directory, in two passes of `Gallery.build`: a
/// keyword and a *person* whose names urlify alike collide the same way,
/// with the person's page landing on top. One name cannot be in both
/// buckets — `applyConfigDerivedFields` re-splits the union of a photo's
/// keywords and people against `allPeople`, so the bucket is a function of
/// the name — but two names that urlify alike can be, one in each.
///
/// Separate from ``findOutputPathCollisions(ctx:)`` because these names
/// exist only after every photo's EXIF has been read. It still runs
/// before anything is written, which is what the guarantee actually
/// needs: `Gallery.load` raises it, so `build` never starts.
///
/// Keyed by the url's bytes for the same reason the filename walk is:
/// `Håkon` spelled NFC and NFD urlify to two byte-distinct pages and are
/// not a collision. (They are a *different* defect — the aggregation in
/// `buildKeywordsFromAlbum` merges the two names into one entry and drops
/// one of the two urls, leaving the dropped one dangling. FUTURES.md item
/// 14; fixing it means deciding whether two spellings are one keyword.)
func findKeywordOutputPathCollisions(album: Album) -> [OutputPathCollision] {
  var claims: [FilePath: [String]] = [:]
  for pointer in album.keywords {
    claims[pointer.url.path, default: []].append("keyword \"\(pointer.name)\"")
  }
  for pointer in album.people {
    claims[pointer.url.path, default: []].append("person \"\(pointer.name)\"")
  }

  return
    claims
    .filter { $0.value.count > 1 }
    .map {
      OutputPathCollision(
        outputPath: $0.key.string, sources: $0.value.sorted(by: canonicalThenBytewiseLess))
    }
    .sorted { canonicalThenBytewiseLess($0.outputPath, $1.outputPath) }
}

/// Claims made against one album directory, keyed by the leaf name that
/// will be created inside it.
///
/// Keyed by `FilePath` rather than `String` on purpose: `FilePath`
/// compares its bytes, whereas Swift `String` compares canonical
/// equivalence classes. `Håkon.jpg` spelled NFC and NFD are two different
/// files on Linux and get two different output files, so keying by
/// `String` would report them as a collision they are not.
private func collectOutputPathCollisions(
  sourcePath: String,
  outputPath: String,
  isRoot: Bool,
  extensions: Set<String>,
  into found: inout [OutputPathCollision]
) {
  var claims: [FilePath: [String]] = [:]

  // The album's own listing, and — at the root — the two gallery-wide
  // files `Album.expectedFiles` puts beside it. (`Statistics.write` and
  // `Locations.write` currently derive their directory from the raw
  // gallery `name` rather than the urlified one, which is a separate
  // pre-existing bug — see FUTURES.md item 14. Claiming them here at the
  // urlified root matches where they belong.)
  claims["index.json", default: []].append(sourcePath)
  if isRoot {
    claims["stats.json", default: []].append(sourcePath)
    claims["locations.json", default: []].append(sourcePath)
  }

  let directories = directoryNames(under: FilePath(sourcePath))
  for directory in directories {
    claims[FilePath(urlifyName(directory)), default: []]
      .append(joinPath(sourcePath, directory))
  }

  for file in fileOrSymlinkNames(under: FilePath(sourcePath)) {
    let filePath = joinPath(sourcePath, file)
    guard extensions.contains(fileExtension(atPath: filePath) ?? "") else { continue }
    claims[FilePath("\(fileNameWithoutExtension(atPath: filePath)).json"), default: []]
      .append(filePath)
  }

  for (leaf, sources) in claims where sources.count > 1 {
    found.append(
      OutputPathCollision(
        outputPath: joinPath(outputPath, leaf.string),
        sources: sources.sorted(by: canonicalThenBytewiseLess)))
  }

  for directory in directories {
    collectOutputPathCollisions(
      sourcePath: joinPath(sourcePath, directory),
      outputPath: joinPath(outputPath, urlifyName(directory)),
      isRoot: false,
      extensions: extensions,
      into: &found)
  }
}
