import Foundation

/// Decodes a JSON array leniently: each element is decoded independently, and
/// an element that fails is SKIPPED rather than failing the whole array.
///
/// This matters specifically because the natural alternative —
/// `try? container.decode([T].self, forKey: key)` — fails ALL-OR-NOTHING: one
/// malformed item in a 40-item list silently discards all 40, reverting a
/// user's customized, irreplaceable history to defaults with no signal that
/// anything was lost. For import of real user data, losing one bad element is
/// an acceptable, reportable outcome; losing the whole collection is not.
///
/// Returns the successfully-decoded elements plus a count of how many were
/// skipped, so the importer can surface that count to the user instead of
/// staying silent about partial data loss.
public struct LenientArrayResult<T> {
    public var elements: [T]
    public var skippedCount: Int
}

public func decodeLeniently<T: Decodable, Key: CodingKey>(
    _ type: T.Type,
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key
) -> LenientArrayResult<T> {
    guard var unkeyed = try? container.nestedUnkeyedContainer(forKey: key) else {
        return LenientArrayResult(elements: [], skippedCount: 0)
    }
    var out: [T] = []
    var skipped = 0
    // superDecoder() is the reliable primitive here: its documented contract
    // is to advance the container's cursor to the next element as part of
    // vending a decoder for the CURRENT one — independent of whether
    // decoding from that sub-decoder succeeds. Deliberately NOT using
    // `try? unkeyed.decode(T.self)` directly in the loop condition: whether
    // a throwing decode leaves the cursor advanced or stuck is
    // implementation-defined, not a documented guarantee, and depending on
    // it risks either an infinite loop on a bad element or (worse) silently
    // consuming an extra GOOD element alongside a bad one. Routing every
    // element through superDecoder() first sidesteps that uncertainty
    // entirely — advancement and decode-attempt are cleanly separated.
    while !unkeyed.isAtEnd {
        guard let subDecoder = try? unkeyed.superDecoder() else { break }
        if let el = try? T(from: subDecoder) {
            out.append(el)
        } else {
            skipped += 1
        }
    }
    return LenientArrayResult(elements: out, skippedCount: skipped)
}

/// Same guarantee as `decodeLeniently` above, for a keyed dictionary rather
/// than an array. Used for `days`, which is potentially months of a real
/// user's irreplaceable history keyed by date — a single corrupted day entry
/// must never be able to take the rest of the calendar down with it.
public struct LenientDictResult<T> {
    public var elements: [String: T]
    public var skippedKeys: [String]
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

public func decodeLeniently<T: Decodable, Key: CodingKey>(
    _ type: T.Type,
    from container: KeyedDecodingContainer<Key>,
    forDictKey key: Key
) -> LenientDictResult<T> {
    // Decode through a dynamic keyed container so each entry can be attempted
    // independently and a single malformed value does not discard the rest.
    guard let outer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key) else {
        return LenientDictResult(elements: [:], skippedKeys: [])
    }
    var out: [String: T] = [:]
    var skipped: [String] = []
    for k in outer.allKeys {
        if let v = try? outer.decode(T.self, forKey: k) {
            out[k.stringValue] = v
        } else {
            skipped.append(k.stringValue)
        }
    }
    return LenientDictResult(elements: out, skippedKeys: skipped)
}
