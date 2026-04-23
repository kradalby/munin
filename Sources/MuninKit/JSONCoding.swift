import Foundation

/// Canonical JSON encoders/decoders used everywhere Munin writes or reads
/// its own files. Centralising the configuration keeps the on-disk format
/// stable and makes the stability guarantees obvious:
///
/// - `.sortedKeys` — object keys appear in lexicographic order, so
///   byte-identical input produces byte-identical output across runs,
///   platforms, and Swift toolchains. Without this the output would vary
///   with `Dictionary` hashing, which is per-process randomised.
/// - `.withoutEscapingSlashes` — gallery paths stay readable
///   (`"content/root/index.json"` instead of `"content\/root\/index.json"`).
///   Downstream Hugin consumers parse either form but humans read the diff.
/// - `.iso8601` date encoding — matches the existing on-disk layout;
///   changing this would force a full re-index for anyone upgrading.
enum MuninJSON {

  /// Encoder used for every `*.json` file Munin writes to disk.
  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  /// Decoder used for every `*.json` file Munin reads back. Paired with
  /// `encoder()` so a round-trip of Munin-written JSON is lossless.
  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
