/// Ключи локальных данных с префиксом пользователя `user:{userId}:{baseKey}`.
///
/// Без сервера каждый аккаунт — отдельное поддерево ключей на устройстве.
class UserStorageKeys {
  UserStorageKeys._();

  static String forUser(String userId, String baseKey) => 'user:$userId:$baseKey';

  /// Строковые данные в Secure Storage (JSON payload).
  static const secureStringBases = <String>[
    'notes',
    'state_entries',
    'calendar_entries',
    'user_profile_v1',
  ];

  /// Флаги и числа в SharedPreferences (остаются prefs, но изолированы по userId).
  static const prefsOnlyBases = <String>[
    'neural_insights_model',
    'neural_insights_trained',
    'neural_insights_version',
    'neural_last_retrain_count',
    'local_insights_patterns',
    'qm_insight_events_v1',
    'qm_rec_feedback_v1',
    'qm_offline_validation_v1',
    'insights_ab_mode',
    'insights_ab_updated_at',
    'insights_ab_manual_mode',
    'stats_foundation_sync_week_start_v1',
    'stats_foundation_sync_week_end_v1',
    'foundation_overall_display_smooth_v1',
    'foundation_weight_survey_v1',
    'rec_personalizer_last_variants_v1',
    'insights_expectations_dialog_v1',
    'stats_dashboard_unlocked_via_center_plus_v1',
    'insights_personal_lexicon_v1',
    'foundation_goals_v1',
    'foundation_quest_done_date_v1',
  ];

  static List<String> get allScopedBases => <String>{
        ...secureStringBases,
        ...prefsOnlyBases,
      }.toList();
}
