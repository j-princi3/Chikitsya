import 'package:chikitsya/services/database_service.dart';
import 'package:chikitsya/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.requestNotificationsPermission();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    // await Config.load(); 

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final settingsProvider = SettingsProvider();
    await settingsProvider.loadSettings();
    tz.initializeTimeZones();
    await NotificationService.init();
    await DatabaseService.saveAdherence("INIT", true);
    await requestNotificationPermission();

    final profileProvider = ProfileProvider();
    await profileProvider
        .load(); // Await this to ensure it's loaded before runApp

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settingsProvider),
          ChangeNotifierProvider(create: (_) => profileProvider),
        ],
        child: const DischargeCompanionApp(),
      ),
    );
  } catch (e) {
    // Log the error or handle it
    print('Error during app initialization: $e');
    // You can show a dialog or something, but for now, rethrow
    rethrow;
  }
}

class DischargeCompanionApp extends StatelessWidget {
  const DischargeCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('te'), // Telugu
      ],
      theme: ThemeData(
        useMaterial3: true,
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontSizeFactor: settings.largeText ? 1.2 : 1.0),
      ),
      home: const WelcomeScreen(),
    );
  }
}
