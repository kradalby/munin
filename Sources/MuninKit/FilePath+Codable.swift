import Foundation
import SystemPackage

/// `FilePath`'s default `Codable` encoding leaks its internal storage as
/// an object `{"_storage":{"nullTerminatedStorage":[...]}}` — useful for
/// debugging the type but worthless as an on-disk format. Munin's JSON
/// contract is that paths are plain strings (e.g. `"content/root/index.json"`),
/// so we override `encode`/`decode` on `KeyedContainer` to route
/// `FilePath` values through their string representation.
///
/// These overloads win against the generic `encode<T: Encodable>` /
/// `decode<T: Decodable>` overloads at every `container.encode(self.x,
/// forKey: .x)` / `container.decode(FilePath.self, forKey: .x)` call site
/// — including Swift-synthesized `Codable` conformances for types that
/// carry `FilePath` fields.
extension KeyedEncodingContainer {
  mutating func encode(_ value: FilePath, forKey key: K) throws {
    try encode(value.string, forKey: key)
  }

  mutating func encodeIfPresent(_ value: FilePath?, forKey key: K) throws {
    try encodeIfPresent(value?.string, forKey: key)
  }
}

extension KeyedDecodingContainer {
  func decode(_ type: FilePath.Type, forKey key: K) throws -> FilePath {
    let raw = try decode(String.self, forKey: key)
    return FilePath(raw)
  }

  func decodeIfPresent(_ type: FilePath.Type, forKey key: K) throws -> FilePath? {
    guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
    return FilePath(raw)
  }
}

extension SingleValueEncodingContainer {
  mutating func encode(_ value: FilePath) throws {
    try encode(value.string)
  }
}

extension SingleValueDecodingContainer {
  func decode(_ type: FilePath.Type) throws -> FilePath {
    let raw = try decode(String.self)
    return FilePath(raw)
  }
}

extension UnkeyedEncodingContainer {
  mutating func encode(_ value: FilePath) throws {
    try encode(value.string)
  }
}

extension UnkeyedDecodingContainer {
  mutating func decode(_ type: FilePath.Type) throws -> FilePath {
    let raw = try decode(String.self)
    return FilePath(raw)
  }
}
