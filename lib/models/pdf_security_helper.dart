import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../views/widgets/native_ad_widget.dart';

/// Helper to safely load and decrypt PDF documents across all tools.
class PdfSecurityHelper {
  /// Cache for passwords entered during the session to avoid prompting repeatedly
  static final Map<String, String> _sessionPasswordCache = {};

  /// Clears cached passwords if needed
  static void clearCache() => _sessionPasswordCache.clear();

  /// Attempts to open a PDF file. If it is password protected, prompts the user
  /// with a clean dialog for the password and returns an unlocked [UnlockedPdfResult].
  static Future<UnlockedPdfResult?> openPdfSafely({
    required BuildContext context,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      if (!context.mounted) return null;
      return await openPdfBytesSafely(
        context: context,
        bytes: bytes,
        fileName: file.path.split('/').last,
        filePathKey: file.path,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Attempts to load PDF bytes. If protected, checks session cache or prompts user.
  static Future<UnlockedPdfResult?> openPdfBytesSafely({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String? filePathKey,
  }) async {
    // 1. Try opening normally (no password)
    try {
      final doc = PdfDocument(inputBytes: bytes);
      return UnlockedPdfResult(
        document: doc,
        bytes: bytes,
        wasEncrypted: false,
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isEncrypted = errStr.contains('encrypted') ||
          errStr.contains('password') ||
          errStr.contains('cannot open');

      if (!isEncrypted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid or corrupted PDF: $fileName'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }
    }

    // 2. Check if we already have the password cached for this file in this session
    final cacheKey = filePathKey ?? fileName;
    if (_sessionPasswordCache.containsKey(cacheKey)) {
      final cachedPwd = _sessionPasswordCache[cacheKey]!;
      try {
        final doc = PdfDocument(inputBytes: bytes, password: cachedPwd);
        return UnlockedPdfResult(
          document: doc,
          bytes: bytes,
          wasEncrypted: true,
          password: cachedPwd,
        );
      } catch (_) {
        _sessionPasswordCache.remove(cacheKey);
      }
    }

    // 3. Prompt user for password
    if (!context.mounted) return null;

    final unlocked = await _promptPasswordAndUnlock(
      context: context,
      bytes: bytes,
      fileName: fileName,
      cacheKey: cacheKey,
    );

    return unlocked;
  }

  /// Shows the password unlock dialog loop until user enters correct password or cancels
  static Future<UnlockedPdfResult?> _promptPasswordAndUnlock({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required String cacheKey,
  }) async {
    final passwordController = TextEditingController();
    bool isObscured = true;
    String? errorMessage;

    while (context.mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Color(0xFFE5252A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Password Protected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The file "$fileName" is encrypted. Enter its password to continue:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: isObscured,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                      errorText: errorMessage,
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5252A), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => Navigator.pop(ctx, true),
                  ),
                  const SizedBox(height: 12),
                  // Native Ad inside Password Unlock Dialog
                  const NativeAdWidget(templateType: NativeTemplateStyleType.small),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5252A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        ),
      );

      // User tapped Cancel
      if (result != true) {
        return null;
      }

      final enteredPassword = passwordController.text;
      if (enteredPassword.isEmpty) {
        errorMessage = 'Password cannot be empty';
        continue;
      }

      // Try unlocking with the entered password
      try {
        final doc = PdfDocument(
          inputBytes: bytes,
          password: enteredPassword,
        );

        // Cache password for this session
        _sessionPasswordCache[cacheKey] = enteredPassword;

        return UnlockedPdfResult(
          document: doc,
          bytes: bytes,
          wasEncrypted: true,
          password: enteredPassword,
        );
      } catch (e) {
        errorMessage = 'Incorrect password. Please try again.';
      }
    }

    return null;
  }
}

/// Result returned after unlocking a PDF
class UnlockedPdfResult {
  final PdfDocument document;
  final Uint8List bytes;
  final bool wasEncrypted;
  final String? password;

  UnlockedPdfResult({
    required this.document,
    required this.bytes,
    required this.wasEncrypted,
    this.password,
  });

  void dispose() {
    document.dispose();
  }
}
