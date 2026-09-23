import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// One generic key/payload/fetchedAt table rather than a separate normalized
/// Drift table per cached entity -- same reasoning and shape as Proximity's
/// core/cache/app_database.dart: every cached provider already has its own
/// typed Dart model with fromJson/toJson, so local storage only needs to
/// answer "give me the JSON I last wrote under this key, and when."
class CacheEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

@DriftDatabase(tables: [CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<CacheEntry?> readEntry(String key) {
    return (select(cacheEntries)..where((t) => t.cacheKey.equals(key))).getSingleOrNull();
  }

  Future<void> writeEntry(String key, String jsonPayload) {
    return into(cacheEntries).insertOnConflictUpdate(
      CacheEntriesCompanion.insert(cacheKey: key, payload: jsonPayload, fetchedAt: DateTime.now()),
    );
  }
}

// drift_flutter's own documented setup (drift.simonbinder.eu/setup) --
// resolves a real per-app storage directory and works around sqlite3's
// "wants /tmp, which Android forbids" issue, so no manual path-joining here.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'fitcoach_cache', native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory));
}
