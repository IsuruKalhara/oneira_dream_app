import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences prefs;
  SettingsService(this.prefs);

  static const _onboarded = 'onboarded';
  static const _reminder = 'reminder_enabled';

  bool get onboarded => prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => prefs.setBool(_onboarded, v);

  bool get reminderEnabled => prefs.getBool(_reminder) ?? false;
  Future<void> setReminderEnabled(bool v) => prefs.setBool(_reminder, v);
}
