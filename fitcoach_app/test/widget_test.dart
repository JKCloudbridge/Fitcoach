// Milestone 0 -- dependency-free placeholder smoke test only. FitCoachApp
// itself needs Supabase.initialize (real network) before it can build, which
// needs a mocked SupabaseClient to test properly -- deferred to a dedicated
// testing pass once auth (Milestone 1) exists, same gap baker_ally's own
// Milestone 1 notes flag for the same reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder widget renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('FitCoach')));
    expect(find.text('FitCoach'), findsOneWidget);
  });
}
