import 'package:envied/envied.dart';

part 'env.g.dart';

/// Build-time config from `.env` -- same envied pattern as Baker Ally's and
/// Proximity's core/config/env.dart. Only client-safe values belong here:
/// the anon key is meant to be public (RLS/service-role boundary protects
/// data, not this key).
@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static const String supabaseAnonKey = _Env.supabaseAnonKey;

  // Base URL for Supabase Edge Functions, e.g.
  // https://<ref>.supabase.co/functions/v1 -- each domain-grouped function
  // (workout-api, coaching-api, programs-api, ...) is appended by the
  // repository that calls it, per Plan.md's "Backend Setup" section, rather
  // than every request sharing one flat API_BASE_URL the way the
  // single-function sibling apps do.
  @EnviedField(varName: 'EDGE_FUNCTIONS_BASE_URL')
  static const String edgeFunctionsBaseUrl = _Env.edgeFunctionsBaseUrl;

  @EnviedField(varName: 'GOOGLE_IOS_CLIENT_ID')
  static const String googleIosClientId = _Env.googleIosClientId;

  @EnviedField(varName: 'GOOGLE_SERVER_CLIENT_ID')
  static const String googleServerClientId = _Env.googleServerClientId;
}
