import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily "time to practise" reminder (Android + Windows).
///
/// Instead of one repeating notification, the next [_days] days are
/// scheduled one by one. That way:
///  - it works the same on Windows (which has no repeating schedule), and
///  - today's reminder is skipped once today's goal is already done.
/// The schedule is refreshed every time the app starts or the goal is met.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _baseId = 4200;
  static const _days = 14;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'LexiFlip',
          appUserModelId: 'Uz.LexiFlip.App.1',
          guid: '6f1c2b8e-4c1d-4b7a-9f3e-2d5a8c7b1e90',
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (e) {
      debugPrint('Reminder init failed: $e');
    }
    return _ready;
  }

  /// Asks for permission where needed (Android 13+). Returns false if denied.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Reminder permission failed: $e');
    }
    return true;
  }

  /// (Re)schedules the reminder. [skipToday] when today's goal is done.
  Future<void> schedule({
    required bool enabled,
    required int hour,
    required int minute,
    required bool skipToday,
    required String title,
    required String body,
  }) async {
    if (!await _init()) return;
    try {
      for (var i = 0; i < _days; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!enabled) return;

      final now = DateTime.now();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'Reminds you to practise your words',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        windows: WindowsNotificationDetails(),
      );
      for (var i = 0; i < _days; i++) {
        final day = DateTime(now.year, now.month, now.day + i, hour, minute);
        if (!day.isAfter(now)) continue;
        if (i == 0 && skipToday) continue;
        await _plugin.zonedSchedule(
          id: _baseId + i,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(day, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Reminder schedule failed: $e');
    }
  }
}
