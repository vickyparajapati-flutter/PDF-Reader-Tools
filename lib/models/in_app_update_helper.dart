import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateHelper {
  /// Checks for Google Play In-App Updates and triggers flexible or immediate update.
  static Future<void> checkForUpdate(BuildContext context) async {
    // In-App Updates are only supported on Android devices via Google Play
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // High priority / critical updates: Force immediate update
        if ((updateInfo.updatePriority) >= 4) {
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Standard / flexible update in background
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            // Once download finishes, prompt user to restart and install
            if (context.mounted) {
              _showRestartSnackBar(context);
            }
          }
        } else if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      // In debug mode or if not installed from Google Play, this will throw harmlessly
      debugPrint('[InAppUpdateHelper] Update check info: $e');
    }
  }

  static void _showRestartSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'An update has been downloaded!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: const Color(0xFFE5252A),
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[InAppUpdateHelper] Failed to complete flexible update: $e');
            }
          },
        ),
      ),
    );
  }
}

