import 'dart:convert';

import '../models/user_profile.dart';
import 'auth_service.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';
import 'user_scoped_store.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _keyProfile = 'user_profile_v1';

  Future<UserProfile> load() async {
    final cloud = await FirestoreRepository.instance.loadProfileFields();
    if (cloud != null && cloud.isNotEmpty) {
      final name = (cloud[FirestoreRepository.fieldProfileName] as String? ?? '').trim();
      final conditions = (cloud[FirestoreRepository.fieldProfileConditions] as List<dynamic>? ?? [])
          .map((e) => MentalConditionX.fromCode('$e'))
          .whereType<MentalCondition>()
          .toList();
      final priorityFocus = PriorityStateFocusX.fromCode(
        cloud[FirestoreRepository.fieldProfilePriority] as String?,
      );
      return UserProfile(
        name: name,
        conditions: conditions,
        priorityFocus: priorityFocus,
      );
    }

    final key = await UserScopedStore.scopedKey(_keyProfile);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return const UserProfile();
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final name = (m['name'] as String? ?? '').trim();
      final conditions = (m['conditions'] as List<dynamic>? ?? [])
          .map((e) => MentalConditionX.fromCode('$e'))
          .whereType<MentalCondition>()
          .toList();
      final priorityFocus = PriorityStateFocusX.fromCode(
        m['priorityFocus'] as String?,
      );
      return UserProfile(
        name: name,
        conditions: conditions,
        priorityFocus: priorityFocus,
      );
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> save(UserProfile profile) async {
    final login = await AuthService.instance.username();
    await FirestoreRepository.instance.saveProfileFields(
      name: profile.name.trim(),
      conditions: profile.conditions.map((e) => e.code).toList(),
      priorityFocus: profile.priorityFocus.code,
      loginUsername: login ?? '',
    );

    final key = await UserScopedStore.scopedKey(_keyProfile);
    await SecureKvService.instance.writeString(
      key,
      jsonEncode({
        'name': profile.name.trim(),
        'conditions': profile.conditions.map((e) => e.code).toList(),
        'priorityFocus': profile.priorityFocus.code,
      }),
    );
  }
}
