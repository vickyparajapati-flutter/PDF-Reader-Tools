import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/storage_helper.dart';
import '../models/pdf_security_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';

class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isProtecting = false;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
  }

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        });

        if (!mounted) return;
        final unlocked = await PdfSecurityHelper.openPdfSafely(
          context: context,
          file: file,
        );

        if (unlocked == null) {
          setState(() => _isLoadingPdf = false);
          return;
        }

        final pageCount = unlocked.document.pages.count;
        final cleanBytes = unlocked.bytes;
        unlocked.dispose();

        final baseName = file.path.split('/').last.replaceAll('.pdf', '');
        final uniqueStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        _fileNameController.text = '${baseName}_protected_$uniqueStamp';

        setState(() {
          _sourceFile = file;
          _sourceBytes = cleanBytes;
          _totalPages = pageCount;
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      _showSnackbar('Error reading PDF: $e');
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

  Future<void> _protectPdf() async {
    if (_sourceFile == null) {
      _showSnackbar('Please select a PDF file first.');
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      _showSnackbar('Please enter a password.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackbar('Passwords do not match. Please re-check.');
      return;
    }

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'Protected_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    setState(() => _isProtecting = true);

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final PdfDocument doc = PdfDocument(inputBytes: bytes);

      // Apply Standard AES 256-bit / 128-bit encryption
      final PdfSecurity security = doc.security;
      security.userPassword = password;
      security.ownerPassword = '${password}_admin';
      security.algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6;

      final List<int> protectedBytes = await doc.save();
      doc.dispose();

      // Save to temp then export to Android public MediaStore Downloads
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(protectedBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: fileName,
      );

      setState(() => _isProtecting = false);

      if (!mounted) return;
      InterstitialAdManager().showAd(
        onDismissed: () {
          if (!mounted) return;
          _showSuccessDialog(publicSavedPath, fileName, password);
        },
      );
    } catch (e) {
      setState(() => _isProtecting = false);
      _showSnackbar('Failed to protect PDF: $e');
    }
  }

  void _showSuccessDialog(String path, String name, String password) {
    final file = File(path);
    final sizeInBytes = file.existsSync() ? file.lengthSync() : 0;
    String sizeStr = '';
    if (sizeInBytes < 1024 * 1024) {
      sizeStr = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      sizeStr = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF3949AB).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFF3949AB),
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'PDF Protected Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3949AB),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_totalPages pages • $sizeStr • AES-256 Encrypted',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 14),

            // Password reminder badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.key_rounded, size: 16, color: Color(0xFF555555)),
                  const SizedBox(width: 6),
                  Text(
                    'Password: $password',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Native Ad inside Protect Success Dialog
            const NativeAdWidget(templateType: NativeTemplateStyleType.small),

            const SizedBox(height: 14),

            // Open in Viewer Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3949AB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.visibility_rounded, size: 20),
                label: const Text(
                  'Open in Viewer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfViewerScreen(
                        filePath: path,
                        fileName: name,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Share Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E1E1E),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text(
                  'Share Locked PDF',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(path)],
                      text: 'Protected PDF created with PDF Reader & Tools',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Go back to Tools Tab
              },
              child: const Text('Done', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
          ],
        ),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Protect PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: _isProtecting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF3949AB)),
                  SizedBox(height: 20),
                  Text(
                    'Encrypting Document...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Applying AES-256 Bit Encryption',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3949AB)),
                )
              : _sourceFile == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3949AB).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 48,
                              color: Color(0xFF3949AB),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Lock PDF with Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Select any PDF to secure it with strong encryption',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3949AB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 13),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.file_open_rounded, size: 20),
                            label: const Text(
                              'Choose PDF File',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: _pickPdf,
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selected File Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3949AB)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Color(0xFF3949AB),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _sourceFile!.path.split('/').last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$_totalPages Total Pages',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _pickPdf,
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      color: Color(0xFF3949AB),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Output Name Box
                          const Text(
                            'OUTPUT FILE NAME',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: TextField(
                              controller: _fileNameController,
                              decoration: const InputDecoration(
                                icon: Icon(Icons.edit_note_rounded,
                                    color: Color(0xFF3949AB)),
                                hintText: 'Enter protected file name...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Password Box
                          const Text(
                            'SET PASSWORD',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                icon: const Icon(Icons.lock_outline_rounded,
                                    color: Color(0xFF3949AB)),
                                hintText: 'Enter secure password',
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF8E8E93),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Confirm Password Box
                          const Text(
                            'CONFIRM PASSWORD',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                icon: const Icon(Icons.check_circle_outline_rounded,
                                    color: Color(0xFF3949AB)),
                                hintText: 'Re-enter password to confirm',
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF8E8E93),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3949AB),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFF3949AB)
                                    .withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.lock_rounded, size: 22),
                              label: const Text(
                                'Protect PDF Now',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              onPressed: _protectPdf,
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: BannerAdWidget(),
      ),
    );
  }
}

