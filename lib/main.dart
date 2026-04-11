import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise notifications and re-schedule any saved jadwal reminders so
  // they survive app restarts without requiring the user to open Jadwal screen.
  final notificationService = NotificationService();
  await notificationService.initialize();
  try {
    final savedJadwal = await notificationService.loadSavedJadwal();
    if (savedJadwal.isNotEmpty) {
      await notificationService.scheduleWeeklyClassReminders(savedJadwal);
    }
  } catch (_) {
    // Never block app launch due to notification errors.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'LMS UNINDRA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF073163),
            brightness: Brightness.light,
            primary: const Color(0xFF073163),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF073163),
            brightness: Brightness.dark,
            primary: const Color(0xFF9BC1FF),
          ),
          scaffoldBackgroundColor: const Color(0xFF0C1220),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
