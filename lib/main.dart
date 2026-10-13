import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'dart:developer';


void main() {
  // 🔥 Ловим ошибки Flutter (работает во всех версиях)
  FlutterError.onError = (details) {
    log('❌ FLUTTER ERROR: ${details.exception}');
    log('📍 STACK: ${details.stack}');
  };

  // ❌ УБРАТЬ PlatformDispatcher (недоступен в твоей версии)
  // PlatformDispatcher.instance.onError = ...

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // 👈 ВОТ ЭТО ВАЖНО
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}
