import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The morning reminder. Until this existed the Settings toggle wrote a bool
/// to SharedPreferences and nothing else — a dead switch shipped as a feature.
///
/// One daily local notification at a fixed morning hour. No server, no push
/// infrastructure — everything stays on the device, like the journal.
class NotificationService {
  static const _id = 1001;
  static const _hour = 7;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permissions are requested when the user flips the toggle, not at init —
    // an unprompted permission dialog at app start is how apps get denied.
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios));
    _inited = true;
  }

  /// Enables the daily 07:00 reminder. Returns false when the user denies
  /// notification permission — the caller reverts the toggle and says why.
  Future<bool> enableDaily() async {
    try {
      await _init();

      var granted = true;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? true;
      } else if (ios != null) {
        granted =
            await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      if (!granted) return false;

      // The next local 07:00 as an absolute instant. DateTime.now() carries
      // the device's real offset, so the instant is correct even though
      // tz.local defaults to UTC; the daily repeat then matches wall-clock
      // time and only drifts across DST transitions — acceptable for a nudge.
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, _hour);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: _id,
        title: 'Anything from last night?',
        body: 'Say whatever you remember — even fragments — before it fades.',
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'oneira_reminder',
            'Morning reminder',
            channelDescription: 'A gentle nudge to log your dream on waking',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact is deliberate: exact alarms need a special Android 14
        // permission, and a morning nudge does not need second precision.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (_) {
      // Cancelling a reminder that was never scheduled is not an error.
    }
  }

  /// Test/debug hook: how many notifications are actually scheduled.
  Future<int> pendingCount() async {
    await _init();
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
