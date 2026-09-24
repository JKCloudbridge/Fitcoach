import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import 'notification_models.dart';

/// Direct RLS-gated reads/writes on `notifications` (migration 019) -- always
/// system-written (see that migration's trigger functions), so there is no
/// insert path here at all, only fetch/mark-read.
class NotificationsRepository {
  NotificationsRepository(this._supabase);

  final SupabaseClient _supabase;

  SupabaseClient get supabase => _supabase;

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final rows = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((row) => AppNotification.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Narrowed by migration 019's `grant update (read_at)` -- can never touch
  /// type/payload/user_id even if called incorrectly.
  Future<void> markRead(String notificationId) {
    return _supabase.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) {
    return _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});
