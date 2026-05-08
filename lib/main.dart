import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'services/ad_service.dart';
import 'pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://lwetcjkgspurlhyfufbz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3ZXRjamtnc3B1cmxoeWZ1ZmJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4NzkwNzAsImV4cCI6MjA5MzQ1NTA3MH0.yWF-c4IJBPwMh80K35vYF1hLb7tYWd1vLyMQcxKwdlw',
  );

  try {
    if (Platform.isIOS) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    await AdService().initialize();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: KokColors.background,
    ),
  );

  runApp(const KokApp());
}

class KokApp extends StatelessWidget {
  const KokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: MaterialApp(
        title: 'KOK',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashPage(),
      ),
    );
  }
}
