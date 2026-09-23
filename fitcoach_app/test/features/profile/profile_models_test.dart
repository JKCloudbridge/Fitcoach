import 'package:flutter_test/flutter_test.dart';

import 'package:fitcoach_app/features/profile/data/profile_models.dart';

void main() {
  group('parseCommaSeparated', () {
    test('trims whitespace and drops empty entries', () {
      expect(parseCommaSeparated(' NASM ,  ACE ,, CPR '), ['NASM', 'ACE', 'CPR']);
    });

    test('returns an empty list for blank input', () {
      expect(parseCommaSeparated(''), isEmpty);
      expect(parseCommaSeparated('   '), isEmpty);
    });
  });

  group('TrainerProfile.fromMap', () {
    test('defaults missing optional fields', () {
      final profile = TrainerProfile.fromMap({'id': 'user-1'});
      expect(profile.id, 'user-1');
      expect(profile.displayName, isNull);
      expect(profile.certifications, isEmpty);
      expect(profile.isVerified, isFalse);
    });

    test('reads populated fields', () {
      final profile = TrainerProfile.fromMap({
        'id': 'user-1',
        'display_name': 'Jordan',
        'bio': 'Strength coach',
        'certifications': ['NASM', 'ACE'],
        'is_verified': true,
        'avatar_url': 'https://example.com/a.png',
      });
      expect(profile.displayName, 'Jordan');
      expect(profile.certifications, ['NASM', 'ACE']);
      expect(profile.isVerified, isTrue);
    });
  });

  group('ClientProfile.fromMap', () {
    test('parses date_of_birth from an ISO date string', () {
      final profile = ClientProfile.fromMap({'id': 'user-2', 'date_of_birth': '1998-04-12'});
      expect(profile.dateOfBirth, DateTime(1998, 4, 12));
    });

    test('leaves date_of_birth null when absent', () {
      final profile = ClientProfile.fromMap({'id': 'user-2'});
      expect(profile.dateOfBirth, isNull);
      expect(profile.goals, isEmpty);
    });
  });
}
