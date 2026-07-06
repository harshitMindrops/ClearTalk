import 'package:clear_talk/core/theme.dart';
import 'package:clear_talk/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar — light theme ke liye dark icons
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const ClearTalkApp());
}

class ClearTalkApp extends StatelessWidget {
  const ClearTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClearTalk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(), // Auth check splash screen ke andar hai
    );
  }
}
