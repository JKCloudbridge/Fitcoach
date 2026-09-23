import 'dart:convert';

import 'app_database.dart';

/// Thin JSON-encode/decode wrapper around [AppDatabase]'s one cache table.
/// Any cached provider goes through this rather than touching Drift
/// directly, so the TTL comparison lives in exactly one place.
class LocalCache {
  LocalCache(this._db);

  final AppDatabase _db;

  /// `null` for both "never cached" and "cached, but past [ttl]" -- callers
  /// don't need to tell those apart; both mean "show the real loading state,
  /// don't silently serve a stale result."
  Future<T?> read<T>(String key, Duration ttl, T Function(dynamic json) decode) async {
    final entry = await _db.readEntry(key);
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > ttl) return null;
    return decode(jsonDecode(entry.payload));
  }

  Future<void> write(String key, Object? encoded) {
    return _db.writeEntry(key, jsonEncode(encoded));
  }
}
