import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);

  // google_sign_in v7's initialize() must complete before anything else
  // touches GoogleSignIn.instance -- same init order as Proximity's
  // main.dart. GOOGLE_SERVER_CLIENT_ID must be a Web OAuth client ID, not
  // Android/iOS (see Milestone 1 manual steps). Wrapped defensively --
  // unlike Proximity, FitCoach's .env still has a placeholder client ID
  // until those manual steps are done, and a bad ID shouldn't crash app
  // boot; it should just make Google sign-in itself fail when tapped.
  try {
    await GoogleSignIn.instance.initialize(serverClientId: Env.googleServerClientId);
  } catch (_) {
    // ignore -- surfaces as a Google sign-in failure at tap time instead
  }

  // Firebase (push/crash) init and its defensive try/catch wrapping land in
  // Milestone 6 -- see Plan.md's Milestone Roadmap.

  runApp(const ProviderScope(child: FitCoachApp()));
}

class FitCoachApp extends ConsumerWidget {
  const FitCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FitCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
