import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/auth_wrapper.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const EventBookApp(),
    ),
  );
}

class EventBookApp extends StatelessWidget {
  const EventBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<AppState, bool>((state) => state.isDarkMode);
    return MaterialApp(
      title: 'EventBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}
