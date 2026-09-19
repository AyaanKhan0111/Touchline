import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/db_service.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/sound_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite FFI initialization
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-warm database extraction and verification
  try {
    await DatabaseService.instance.database;
  } catch (e) {
    debugPrint('Database warm-up note: $e');
  }

  // Pre-warm sound effects and haptic settings (Fix 18)
  try {
    await SoundService.instance.init();
  } catch (e) {
    debugPrint('SoundService init note: $e');
  }

  runApp(
    const ProviderScope(
      child: TouchlineApp(),
    ),
  );
}

class TouchlineApp extends ConsumerWidget {
  const TouchlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    ThemeMode resolvedThemeMode;
    switch (themeMode) {
      case 'light':
        resolvedThemeMode = ThemeMode.light;
        break;
      case 'system':
        resolvedThemeMode = ThemeMode.system;
        break;
      case 'dark':
      default:
        resolvedThemeMode = ThemeMode.dark;
        break;
    }

    return MaterialApp.router(
      title: 'Touchline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: resolvedThemeMode,
      routerConfig: router,
    );
  }
}
