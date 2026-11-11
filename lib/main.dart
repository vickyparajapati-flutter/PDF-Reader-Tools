import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'splash_screen.dart';
import 'models/pro_subscription_manager.dart';
import 'models/in_app_purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProSubscriptionManager.init();
  InAppPurchaseService().initialize();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader – PDF Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE5252A),
          primary: const Color(0xFFE5252A),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
