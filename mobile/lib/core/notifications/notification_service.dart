import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local reminder notifications. There's no backend push infrastructure, so
/// everything is scheduled on-device: one alarm per task with a deadline
/// (cancelled the moment the task is completed or deleted), plus a daily
/// evening nudge. Times are resolved from the device's own clock, so we
/// don't need the tz database's local-zone lookup to be correct — only the
/// absolute instant matters for [zonedSchedule].
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'deadline_reminders';
  static const _channelName = 'Напоминания о задачах';
  static const _dailyDigestId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Напоминания о дедлайнах и невыполненных задачах',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Stable per-task notification id, kept out of the daily-digest id space.
  int _idForTask(String taskId) => 1000 + (taskId.hashCode & 0x7fffffff) % 1000000;

  /// Schedules (or reschedules) a one-off reminder at [deadline]. If the
  /// deadline has already passed, any existing reminder for this task is
  /// cancelled instead — a stale alarm firing after the fact would be noise.
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime deadline,
  }) async {
    final id = _idForTask(taskId);
    if (!deadline.isAfter(DateTime.now())) {
      await _plugin.cancel(id);
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(deadline, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskReminder(String taskId) => _plugin.cancel(_idForTask(taskId));

  /// Reschedules a single generic reminder for the given time today (or
  /// tomorrow if that time has already passed) — re-run this on every app
  /// start/refresh so it keeps rolling forward a day at a time.
  Future<void> scheduleDailyDigest({int hour = 20, int minute = 0}) async {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      _dailyDigestId,
      'DeadlineTracker',
      'Проверьте, все ли задачи на сегодня выполнены',
      tz.TZDateTime.from(next, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
