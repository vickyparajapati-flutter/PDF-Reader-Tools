import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProSubscriptionManager {
  static const String _kIsProUserKey = 'is_pro_user_active';

  /// Global ValueNotifier so UI across the app reacts instantly to Pro status changes
  static final ValueNotifier<bool> isProUserNotifier = ValueNotifier<bool>(false);

  /// Synchronous getter to check if user has PRO
  static bool get isPro => isProUserNotifier.value;

  /// Initialize state from SharedPreferences on app launch
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final bool savedStatus = prefs.getBool(_kIsProUserKey) ?? false;
    isProUserNotifier.value = savedStatus;
  }

  /// Toggle or set Pro status (Flag based)
  static Future<void> setProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProUserKey, isPro);
    isProUserNotifier.value = isPro;
  }
}

