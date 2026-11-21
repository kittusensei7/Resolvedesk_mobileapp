import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/api_config.dart';
import 'pages/login_page.dart';
import 'pages/technician_dashboard_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  runApp(const ResolveDeskApp());
}

class ResolveDeskApp extends StatefulWidget {
  const ResolveDeskApp({super.key});

  @override
  State<ResolveDeskApp> createState() => _ResolveDeskAppState();
}

class _ResolveDeskAppState extends State<ResolveDeskApp> {
  bool _initializing = true;
  Map<String, dynamic>? _savedUser;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final token = await ApiConfig.getToken();
      final user = await ApiConfig.getUser();
      if (token != null && token.isNotEmpty && user != null) {
        if (ApiConfig.isTokenExpired(token)) {
          debugPrint("⚠️ [Startup Check] Stored token is expired. Clearing session.");
          await ApiConfig.clearToken();
        } else {
          if (mounted) {
            setState(() {
              _savedUser = user;
            });
          }
          NotificationService.syncTokenWithServer();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Paradesk Technician',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1e3a8a),
          primary: const Color(0xff2457d6),
          secondary: const Color(0xff0284c7),
          surface: const Color(0xfff8fafc),
        ),
        scaffoldBackgroundColor: const Color(0xfff1f5f9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xff0f172a),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xff94a3b8), fontSize: 13, fontWeight: FontWeight.normal),
          labelStyle: const TextStyle(color: Color(0xff475569), fontSize: 13, fontWeight: FontWeight.w600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff2457d6), width: 2),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: _initializing
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xff2563eb)),
              ),
            )
          : _savedUser != null
              ? TechnicianDashboardPage(user: _savedUser!)
              : const LoginPage(),
    );
  }
}
