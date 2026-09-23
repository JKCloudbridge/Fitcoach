import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';

/// Shared Dio instance for every Edge Function call. baseUrl is the root
/// Edge Functions URL only (e.g. `https://<ref>.supabase.co/functions/v1`) --
/// each feature repository appends its own domain-grouped function's path
/// (workout-api, coaching-api, programs-api, ...) per Plan.md's "Backend
/// Setup" section, since FitCoach splits into several small Hono-routed
/// functions rather than one shared "api" function like the sibling apps.
///
/// Simple reads (Discover, public workout_cards, etc.) bypass this client
/// entirely and go straight through supabase_flutter + RLS -- this client is
/// only for the transactional writes that need Edge Function logic.
Dio buildDioClient(SecureStorage secureStorage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.edgeFunctionsBaseUrl,
      // Bounded rather than left to Dio's default of "wait indefinitely" --
      // a cold-starting Edge Function or dropped connection should surface
      // as an error, not a stuck screen. Same values as proximity_app's
      // dio_client.dart, which hit this live on a real device.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final jwt = await secureStorage.readJwt();
        if (jwt != null) {
          options.headers['Authorization'] = 'Bearer $jwt';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
