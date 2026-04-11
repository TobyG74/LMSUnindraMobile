import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _legacyNotificationStoreDetected = false;
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
    try {
      await _notifications.cancel(id);
    } on PlatformException catch (e) {
      if (_isLegacyTypeIssue(e)) {
        _legacyNotificationStoreDetected = true;
        return;
      }
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } on PlatformException catch (e) {
      if (_isLegacyTypeIssue(e)) {
        _legacyNotificationStoreDetected = true;
        return;
      }
      rethrow;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (_legacyNotificationStoreDetected) {
      return const [];
    }

    try {
      return await _notifications.pendingNotificationRequests();
    } on PlatformException catch (e) {
      if (_isLegacyTypeIssue(e)) {
        _legacyNotificationStoreDetected = true;
        return const [];
      }

      rethrow;
    }
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

  // ---------------------------------------------------------------------------
  // Jadwal persistence
  // ---------------------------------------------------------------------------

  static const String _jadwalPrefsKey = 'saved_jadwal_notifications';

  Future<void> saveJadwalList(List<JadwalItem> jadwalList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(jadwalList.map((j) => j.toJson()).toList());
      await prefs.setString(_jadwalPrefsKey, encoded);
    } catch (_) {
      // Persistence failure must not crash the UI.
    }
  }

  Future<List<JadwalItem>> loadSavedJadwal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_jadwalPrefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => JadwalItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Weekly class reminders  (replaces the old today-only scheduling)
  // ---------------------------------------------------------------------------

  /// Saves [jadwalList] and schedules weekly repeating notifications:
  ///  • at exact class-start time
  ///  • 30 minutes before class start
  /// Safe to call on every jadwal refresh — cancels stale reminders first.
  Future<void> scheduleWeeklyClassReminders(
      List<JadwalItem> jadwalList) async {
    await initialize();

    if (_legacyNotificationStoreDetected) return;

    final granted = await requestPermission();
    if (!granted) return;

    // Persist jadwal so we can re-schedule after app restart.
    await saveJadwalList(jadwalList);

    await cancelClassReminders();

    for (final jadwal in jadwalList) {
      final weekday = _weekdayFromDayName(jadwal.hari);
      if (weekday == null) continue;

      final startTime = _extractStartTime(jadwal.waktu);
      if (startTime == null) continue;

      // ---- At-class-start notification ----
      final startScheduled = _nextInstanceOfDayTime(
          weekday, startTime.hour, startTime.minute);
      final startId = _buildNotifId('start', jadwal);
      final startBody =
          '${jadwal.mataKuliah} dimulai sekarang di ${jadwal.ruang.isEmpty ? 'kelas ${jadwal.kelas}' : 'ruang ${jadwal.ruang}'}';

      await _tryZonedSchedule(
        id: startId,
        title: 'Jadwal Kuliah Dimulai',
        body: startBody,
        scheduledTime: startScheduled,
        channelId: 'class_schedule_reminder',
        channelName: 'Class Schedule Reminders',
        channelDesc: 'Pengingat jadwal kuliah saat mulai dan 30 menit sebelum',
        payload:
            '$_classReminderPayloadPrefix:start:${jadwal.kode}:${jadwal.kelas}',
        repeat: true,
      );

      // ---- 30-minutes-before notification ----
      final reminderScheduled = _nextInstanceOfDayTime(
          weekday,
          startTime.hour,
          startTime.minute,
          subtractMinutes: 30);
      final reminderId = _buildNotifId('before', jadwal);
      final reminderBody =
          '${jadwal.mataKuliah} mulai 30 menit lagi di ${jadwal.ruang.isEmpty ? 'kelas ${jadwal.kelas}' : 'ruang ${jadwal.ruang}'}';

      await _tryZonedSchedule(
        id: reminderId,
        title: 'Pengingat Kuliah',
        body: reminderBody,
        scheduledTime: reminderScheduled,
        channelId: 'class_schedule_reminder',
        channelName: 'Class Schedule Reminders',
        channelDesc: 'Pengingat jadwal kuliah saat mulai dan 30 menit sebelum',
        payload:
            '$_classReminderPayloadPrefix:before:${jadwal.kode}:${jadwal.kelas}',
        repeat: true,
      );
    }
  }

  Future<void> _tryZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String payload,
    required bool repeat,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            ticker: title,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat
            ? DateTimeComponents.dayOfWeekAndTime
            : null,
      );
    } on PlatformException catch (e) {
      if (_isLegacyTypeIssue(e)) {
        _legacyNotificationStoreDetected = true;
        return;
      }
      // Ignore other scheduling errors (e.g. permission denied at OS level).
    }
  }

  bool _isLegacyTypeIssue(PlatformException e) {
    final message = (e.message ?? '').toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    return message.contains('missing type parameter') ||
        details.contains('missing type parameter');
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

  /// Convert an Indonesian day name to a [DateTime] weekday constant.
  int? _weekdayFromDayName(String day) {
    switch (_normalizeDayName(day)) {
      case 'senin':
        return DateTime.monday;
      case 'selasa':
        return DateTime.tuesday;
      case 'rabu':
        return DateTime.wednesday;
      case 'kamis':
        return DateTime.thursday;
      case 'jumat':
      case "jum'at":
      case 'jum at':
        return DateTime.friday;
      case 'sabtu':
        return DateTime.saturday;
      case 'minggu':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  String _normalizeDayName(String day) {
    final normalized = day.toLowerCase().trim();
    return normalized
        .replaceAll('\u2019', '')
        .replaceAll("'", '')
        .replaceAll('`', '');
  }

  /// Returns the next [tz.TZDateTime] that falls on [weekday] at [hour]:[minute],
  /// optionally shifted back by [subtractMinutes].
  /// The result is always strictly in the future.
  tz.TZDateTime _nextInstanceOfDayTime(
    int weekday,
    int hour,
    int minute, {
    int subtractMinutes = 0,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (subtractMinutes > 0) {
      candidate = candidate.subtract(Duration(minutes: subtractMinutes));
    }

    // Advance day by day until we land on the correct weekday in the future.
    for (int i = 0; i < 8; i++) {
      if (candidate.weekday == weekday && candidate.isAfter(now)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  int _buildNotifId(String type, JadwalItem jadwal) {
    return '$type:${jadwal.kode}:${jadwal.kelas}'.hashCode & 0x7fffffff;
  }
}
