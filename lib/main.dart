import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_gate.dart';
import 'firebase_options.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Muhim bo'lmagan initsializatsiya xato bersa yoki osilib qolsa, ilova
/// ochilishini to'xtatmasligi uchun.
Future<void> _safeInit(
  String name,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    await task().timeout(timeout);
  } catch (e) {
    debugPrint('$name initsializatsiyasi bajarilmadi: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase ishga tushmadi: $e');
    runApp(_BootErrorApp(onRetry: main));
    return;
  }

  await _safeInit('Hive', StorageService.init);
  await _safeInit('Sana formatlari', () => initializeDateFormatting('uz', null));

  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const MyApp());

  // Bildirishnoma ruxsati dialogi va token olish ilova ochilishini kutdirmaydi.
  if (!kIsWeb) {
    unawaited(_safeInit('Bildirishnomalar', NotificationService.instance.init,
        timeout: const Duration(seconds: 20)));
  }
}

class _BootErrorApp extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _BootErrorApp({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "Ilovani ishga tushirib bo'lmadi.\nInternetni tekshirib, qayta urinib ko'ring.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => onRetry(),
                  child: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NatureGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

class AppTheme {
  static const Color primary       = Color(0xFF2E7D32);
  static const Color primaryLight  = Color(0xFF43A047);
  static const Color primaryDark   = Color(0xFF1B5E20);
  static const Color accent        = Color(0xFFFF6F00);
  static const Color bg            = Color(0xFFF0F4F0);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color textMain      = Color(0xFF1C2B1E);
  static const Color textSecondary = Color(0xFF5A7A5C);
  static const Color border        = Color(0xFFD8E8D8);
  static const Color star          = Color(0xFFF59E0B);

  static const Color cardBg        = Color(0xFFF7FAF7);
  static const Color textPrimary   = Color(0xFF1C2B1E);
  static const Color accentWarm    = Color(0xFFFF6B6B);
  static const Color accentGold    = Color(0xFFFFD166);
  static const Color positive      = Color(0xFF00C896);
  static const Color negative      = Color(0xFFFF6B6B);

  static const List<Color> memberColors = [
    Color(0xFFFFB3B3),
    Color(0xFFB3D9FF),
    Color(0xFFB3F0DC),
    Color(0xFFFFE5B3),
    Color(0xFFD9B3FF),
    Color(0xFFFFB3E6),
    Color(0xFFB3FFD9),
    Color(0xFFFFD9B3),
  ];

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
