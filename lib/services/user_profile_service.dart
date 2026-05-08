import 'dart:convert';

import '../models/user_profile.dart';
import 'secure_kv_service.dart';
import 'user_scoped_store.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _keyProfile = 'user_profile_v1';

  Future<UserProfile> load() async {
    final key = await UserScopedStore.scopedKey(_keyProfile);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final name = (m['name'] as String? ?? '').trim();
      final doctorName = (m['doctorName'] as String? ?? '').trim();
      final conditions = (m['conditions'] as List<dynamic>? ?? [])
          .map((e) => MentalConditionX.fromCode('$e'))
          .whereType<MentalCondition>()
          .toList();
      final priorityFocus = PriorityStateFocusX.fromCode(
        m['priorityFocus'] as String?,
      );
      return UserProfile(
        name: name,
        doctorName: doctorName,
        conditions: conditions,
        priorityFocus: priorityFocus,
      );
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> save(UserProfile profile) async {
    final key = await UserScopedStore.scopedKey(_keyProfile);
    await SecureKvService.instance.writeString(
      key,
      jsonEncode({
        'name': profile.name.trim(),
        'doctorName': profile.doctorName.trim(),
        'conditions': profile.conditions.map((e) => e.code).toList(),
        'priorityFocus': profile.priorityFocus.code,
      }),
    );
  }
}
