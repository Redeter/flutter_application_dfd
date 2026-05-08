import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _keyProfile = 'user_profile_v1';

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyProfile,
      jsonEncode({
        'name': profile.name.trim(),
        'doctorName': profile.doctorName.trim(),
        'conditions': profile.conditions.map((e) => e.code).toList(),
        'priorityFocus': profile.priorityFocus.code,
      }),
    );
  }
}
