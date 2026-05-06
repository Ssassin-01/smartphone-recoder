import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartphone_recorder/core/app_theme.dart';
import 'package:smartphone_recorder/presentation/screens/home_screen.dart';
import 'package:smartphone_recorder/overlay/overlay_widget.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SmartphoneRecorderApp(),
    ),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  print('🔵 [overlayMain] Flutter 오버레이 엔진 시작!');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          surface: Colors.transparent,
        ),
      ),
      home: const OverlayWidget(),
    ),
  );
}

class SmartphoneRecorderApp extends StatelessWidget {
  const SmartphoneRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartphone Recorder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
