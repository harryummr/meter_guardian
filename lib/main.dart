import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/meter_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.instance.init();
  await NotificationService.instance.init();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(MeterGuardianApp(themeProvider: themeProvider));
}

class MeterGuardianApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const MeterGuardianApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => MeterProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Meter Guardian',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
