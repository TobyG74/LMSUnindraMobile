import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/jadwal_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _classReminderPayloadPrefix = 'class_reminder';

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted =
          await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  Future<void> scheduleAssignmentReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'assignment_reminder',
      'Assignment Reminders',
      channelDescription: 'Pengingat deadline tugas',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Pengingat Tugas',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> cancelClassReminders() async {
    await initialize();
    final pending = await getPendingNotifications();

    for (final item in pending) {
      final payload = item.payload ?? '';
      if (payload.startsWith(_classReminderPayloadPrefix)) {
        await _notifications.cancel(item.id);
      }
    }
  }

  Future<void> scheduleTodayClassReminders(List<JadwalItem> jadwalList) async {
    await initialize();

    final granted = await requestPermission();
    if (!granted) {
      return;
    }

    await cancelClassReminders();

    final now = DateTime.now();
    final todayName = _dayNameFromWeekday(now.weekday);

    for (final jadwal in jadwalList) {
      if (_normalizeDayName(jadwal.hari) != todayName) {
        continue;
      }

      final startTime = _extractStartTime(jadwal.waktu);
      if (startTime == null) {
        continue;
      }

      final classStart = DateTime(
        now.year,
        now.month,
        now.day,
        startTime.hour,
        startTime.minute,
      );

      final reminderTime = classStart.subtract(const Duration(minutes: 30));
      if (!reminderTime.isAfter(now)) {
        continue;
      }

      final notificationId = _buildReminderId(jadwal, classStart);
      final title = 'Pengingat Kuliah';
      final body =
          '${jadwal.mataKuliah} mulai pukul ${_twoDigits(startTime.hour)}:${_twoDigits(startTime.minute)} di ${jadwal.ruang.isEmpty ? 'kelas ${jadwal.kelas}' : 'ruang ${jadwal.ruang}'}';

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'class_schedule_reminder',
          'Class Schedule Reminders',
          channelDescription: 'Pengingat jadwal kuliah 30 menit sebelum mulai',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Pengingat Jadwal Kuliah',
        ),
      );

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(reminderTime, tz.local),
        details,
        payload:
            '$_classReminderPayloadPrefix:${jadwal.kode}:${classStart.toIso8601String()}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  DateTime? _extractStartTime(String waktu) {
    final match = RegExp(r'(\d{1,2})[:\.](\d{2})').firstMatch(waktu);
    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');

    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }

    return DateTime(2000, 1, 1, hour, minute);
  }

  String _dayNameFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'senin';
      case DateTime.tuesday:
        return 'selasa';
      case DateTime.wednesday:
        return 'rabu';
      case DateTime.thursday:
        return 'kamis';
      case DateTime.friday:
        return 'jumat';
      case DateTime.saturday:
        return 'sabtu';
      default:
        return 'minggu';
    }
  }

  String _normalizeDayName(String day) {
    final normalized = day.toLowerCase().trim();
    return normalized
        .replaceAll('’', '')
        .replaceAll("'", '')
        .replaceAll('`', '');
  }

  int _buildReminderId(JadwalItem jadwal, DateTime classStart) {
    final base =
        '${jadwal.kode}_${jadwal.kelas}_${classStart.toIso8601String()}';
    return base.hashCode & 0x7fffffff;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
