import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/storage_helper.dart';
import '../models/pdf_security_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';

class UnlockPdfScreen extends StatefulWidget {
  const UnlockPdfScreen({super.key});

  @override
  State<UnlockPdfScreen> createState() => _UnlockPdfScreenState();
}

class _UnlockPdfScreenState extends State<UnlockPdfScreen> {
  File? _selectedFile;
  bool _isLoadingPdf = false;
  bool _isUnlocking = false;
  int _totalPages = 0;
  String? _knownPassword;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
  }

  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        setState(() {
          _isLoadingPdf = true;
          _selectedFile = file;
          _totalPages = 0;
          _knownPassword = null;
        });

        final bytes = await file.readAsBytes();
        
        // Check if document has password
        bool isProtected = false;
        int pageCount = 0;

        try {
          final testDoc = PdfDocument(inputBytes: bytes);
          pageCount = testDoc.pages.count;
          testDoc.dispose();
          isProtected = false;
        } catch (_) {
          isProtected = true;
        }

        final baseName = file.path.split('/').last.replaceAll('.pdf', '');
        final uniqueStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        _fileNameController.text = '${baseName}_unlocked_$uniqueStamp';

        setState(() {
          _isLoadingPdf = false;
          _totalPages = pageCount;
        });

        if (isProtected) {
          // Trigger password prompt immediately
          if (!mounted) return;
          final unlocked = await PdfSecurityHelper.openPdfSafely(
            context: context,
            file: file,
          );

          if (unlocked != null) {
            setState(() {
              _totalPages = unlocked.document.pages.count;
              _knownPassword = unlocked.password;
              if (unlocked.password != null) {
                _passwordController.text = unlocked.password!;
              }
            });
            unlocked.dispose();
          } else {
            // User cancelled unlock dialog
            setState(() {
              _selectedFile = null;
            });
          }
        }
      }
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      _showSnackbar('Error reading PDF: $e');
    }
  }

  Future<void> _unlockAndSavePdf() async {
    if (_selectedFile == null) {
      _showSnackbar('Please select a PDF first');
      return;
    }

    final outName = _fileNameController.text.trim();
    if (outName.isEmpty) {
      _showSnackbar('Please enter an output file name');
      return;
    }

    setState(() => _isUnlocking = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final password = _passwordController.text.isNotEmpty ? _passwordController.text : _knownPassword;

      PdfDocument sourceDoc;
      try {
        if (password != null && password.isNotEmpty) {
          sourceDoc = PdfDocument(inputBytes: bytes, password: password);
        } else {
          sourceDoc = PdfDocument(inputBytes: bytes);
        }
      } catch (e) {
        setState(() => _isUnlocking = false);
        _showSnackbar('Incorrect password. Please verify and try again.');
        return;
      }

      // Create completely unencrypted clean copy
      final unencryptedDoc = PdfDocument();
      // Remove any security permissions/encryption
      unencryptedDoc.security.ownerPassword = '';
      unencryptedDoc.security.userPassword = '';

      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final template = sourceDoc.pages[i].createTemplate();
        final newPage = unencryptedDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final cleanBytes = unencryptedDoc.saveSync();
      sourceDoc.dispose();
      unencryptedDoc.dispose();

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/$outName.pdf');
      await tempFile.writeAsBytes(cleanBytes);

      // Save via native MediaStore to /Download/PDFReader/
      final savedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: '$outName.pdf',
      );

      setState(() => _isUnlocking = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(savedPath);
          },
        );
      }
    } catch (e) {
      setState(() => _isUnlocking = false);
      _showSnackbar('Unlock failed: $e');
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00897B), size: 56),
            SizedBox(height: 12),
            Text(
              'PDF Unlocked!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Password has been completely removed. This document can now be opened anywhere without a password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded, color: Color(0xFF00897B), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      filePath.split('/').last,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Native Ad inside Unlock Success Dialog
            const NativeAdWidget(templateType: NativeTemplateStyleType.small),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Tools'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfViewerScreen(
                    filePath: filePath,
                    fileName: filePath.split('/').last,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
            label: const Text('Open PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E1E1E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Unlock PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoadingPdf
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00897B)),
                  SizedBox(height: 14),
                  Text('Analyzing document...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_open_rounded, color: Color(0xFF00897B), size: 30),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permanently Remove Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF00695C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Unlock a password-protected PDF to share or view it without entering the password every time.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF004D40)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // File Selection Card
                if (_selectedFile == null)
                  InkWell(
                    onTap: _pickPdf,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!, width: 1.5),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_upload_outlined, size: 52, color: Color(0xFF00897B)),
                          SizedBox(height: 12),
                          Text(
                            'Select Password-Protected PDF',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap to browse files',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF00897B), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile!.path.split('/').last,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _totalPages > 0
                                        ? '$_totalPages Pages • Protected'
                                        : 'Password Protected Document',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00897B)),
                              tooltip: 'Change File',
                              onPressed: _pickPdf,
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Password Field
                        const Text(
                          'DOCUMENT PASSWORD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter document password to unlock',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Output File Name
                        const Text(
                          'OUTPUT FILE NAME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fileNameController,
                          decoration: InputDecoration(
                            hintText: 'Output file name',
                            suffixText: '.pdf',
                            prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Unlock Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedFile != null && !_isUnlocking) ? _unlockAndSavePdf : null,
                    icon: _isUnlocking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(
                      _isUnlocking ? 'Unlocking & Saving...' : 'Remove Password & Save',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: BannerAdWidget(),
      ),
    );
  }
}
