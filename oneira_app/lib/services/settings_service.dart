import 'package:shared_preferences/shared_preferences.dart';

/// Why the user says they're here. Captured once during onboarding and used to
/// tailor the Record screen's prompt — we don't ask a question we don't use.
/// Stored by [id]; never rename an id without a migration.
enum DreamIntent {
  recall('recall'),
  recurring('recurring'),
  patterns('patterns'),
  curiosity('curiosity');

  const DreamIntent(this.id);
  final String id;

  static DreamIntent? fromId(String? id) {
    if (id == null) return null;
    for (final v in DreamIntent.values) {
      if (v.id == id) return v;
    }
    return null; // unknown id from a newer build — fall back to the default copy
  }
}

class SettingsService {
  final SharedPreferences prefs;
  SettingsService(this.prefs);

  static const _onboarded = 'onboarded';
  static const _reminder = 'reminder_enabled';
  static const _intent = 'dream_intent';
  static const _micPrompted = 'mic_prompted';

  bool get onboarded => prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => prefs.setBool(_onboarded, v);

  bool get reminderEnabled => prefs.getBool(_reminder) ?? false;
  Future<void> setReminderEnabled(bool v) => prefs.setBool(_reminder, v);

  /// Null when the user skipped the question, or onboarded before it existed.
  DreamIntent? get intent => DreamIntent.fromId(prefs.getString(_intent));
  Future<void> setIntent(DreamIntent? v) => v == null
      ? prefs.remove(_intent)
      : prefs.setString(_intent, v.id);

  /// True once we've shown the system microphone prompt. iOS only ever shows it
  /// once per install, so a second "Allow" tap must deep-link to Settings
  /// instead of silently doing nothing.
  bool get micPrompted => prefs.getBool(_micPrompted) ?? false;
  Future<void> setMicPrompted(bool v) => prefs.setBool(_micPrompted, v);
}
