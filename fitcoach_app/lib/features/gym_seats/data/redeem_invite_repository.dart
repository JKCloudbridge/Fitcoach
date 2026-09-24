import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one gym-seats write that needs fitcoach_backend/coaching-api, per
/// CLAUDE.md's hybrid pattern -- redeeming an invite has to validate the
/// code, check seat capacity, and create a coaching_relationships row the
/// redeeming client has no RLS insert path to on their own (see migration
/// 022's redeem_invite()). Creating a subscription/invite stays a direct RLS
/// write on the owning trainer's side (subscriptions_repository.dart /
/// invites_repository.dart).
class RedeemInviteRepository {
  RedeemInviteRepository(this._dio);

  final Dio _dio;

  Future<String> redeem({required String code}) async {
    final response = await _dio.post<Map<String, dynamic>>('/coaching-api/redeem-invite', data: {'code': code});
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['relationshipId'] as String;
  }
}

final redeemInviteRepositoryProvider = Provider<RedeemInviteRepository>((ref) {
  return RedeemInviteRepository(ref.watch(dioProvider));
});

/// Same envelope-unwrapping shape as start_conversation_repository.dart's
/// describeStartConversationError.
String describeRedeemInviteError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not redeem this invite: $error';
}
