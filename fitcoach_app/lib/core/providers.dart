import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache/app_database.dart';
import 'cache/local_cache.dart';
import 'network/dio_client.dart';
import 'storage/secure_storage.dart';

/// Root providers -- alive for the app's lifetime. Feature root providers
/// (authProvider, workoutCardsProvider, ...) live in their own feature
/// folders and build on these, same layering as both sibling apps.

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Only for the transactional writes routed through an Edge Function (see
/// dio_client.dart). Simple reads use [supabaseClientProvider] directly.
final dioProvider = Provider<Dio>((ref) {
  return buildDioClient(ref.watch(secureStorageProvider));
});

/// One Drift database, opened lazily on first read rather than eagerly in
/// main.dart -- nothing needs the cache warm before the first frame.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localCacheProvider = Provider<LocalCache>((ref) {
  return LocalCache(ref.watch(appDatabaseProvider));
});

/// Wraps the process-wide `GoogleSignIn.instance` singleton (initialized once
/// in main.dart before anything touches it -- required by the v7 API) so
/// every consumer goes through Riverpod consistently, same reasoning as
/// Proximity's googleSignInProvider.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});
