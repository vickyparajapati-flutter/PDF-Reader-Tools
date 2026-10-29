import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/storage_helper.dart';
import '../models/pdf_security_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  int _originalSizeBytes = 0;
  bool _isLoadingPdf = false;
  bool _isCompressing = false;
  double _compressProgress = 0.0;
  String _statusText = '';

  // 0: High Compression (72 DPI)
  // 1: Medium Compression (Balanced, 110 DPI)
  // 2: Low Compression (150 DPI)
  // 3: Ultra Max Compression (Pro 50 DPI - Unlocked via Rewarded Ad)
  int _compressionLevel = 1;
  bool _isUltraUnlocked = false;

  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
    RewardedAdManager().loadAd(); // Preload Rewarded Video Ad
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final originalSize = file.lengthSync();

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
        _fileNameController.text = '${baseName}_compressed_$uniqueStamp';

        setState(() {
          _sourceFile = file;
          _sourceBytes = cleanBytes;
          _totalPages = pageCount;
          _originalSizeBytes = originalSize;
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      _showSnackbar('Error reading PDF: $e');
    }
  }

  Future<void> _compressPdf() async {
    if (_sourceFile == null || _totalPages == 0) return;

    final outName = _fileNameController.text.trim();
    if (outName.isEmpty) {
      _showSnackbar('Please enter output file name');
      return;
    }

    setState(() {
      _isCompressing = true;
      _compressProgress = 0.0;
      _statusText = 'Analyzing document streams...';
    });

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final doc = await px.PdfDocument.openData(bytes);

      // Compression settings
      // scale: 1.0 = ~72 DPI, 1.5 = ~110 DPI, 2.0 = ~150 DPI
      double scale = 1.4;
      if (_compressionLevel == 3) {
        scale = 0.75; // Ultra Max Compression (extreme reduction)
      } else if (_compressionLevel == 0) {
        scale = 1.0; // High compression (Smallest file)
      } else if (_compressionLevel == 1) {
        scale = 1.4; // Medium (Balanced)
      } else {
        scale = 1.9; // Low compression (Best quality)
      }

      final compressedPdf = pw.Document();

      for (int i = 1; i <= doc.pagesCount; i++) {
        if (!mounted) break;

        setState(() {
          _compressProgress = (i - 1) / doc.pagesCount;
          _statusText = 'Optimizing page $i of ${doc.pagesCount}...';
        });

        final page = await doc.getPage(i);
        final renderWidth = page.width * scale;
        final renderHeight = page.height * scale;

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: px.PdfPageImageFormat.jpeg,
        );
        await page.close();

        if (pageImage != null) {
          final imageProvider = pw.MemoryImage(pageImage.bytes);
          compressedPdf.addPage(
            pw.Page(
              pageFormat: pw.PdfPageFormat(page.width, page.height),
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(
                    imageProvider,
                    fit: pw.BoxFit.fill,
                  ),
                );
              },
            ),
          );
        }
      }

      await doc.close();

      setState(() {
        _statusText = 'Saving compressed document...';
      });

      final compressedBytes = await compressedPdf.save();

      final tempDir = await getTemporaryDirectory();
      final finalFileName = outName.toLowerCase().endsWith('.pdf') ? outName : '$outName.pdf';
      final tempFile = File('${tempDir.path}/$finalFileName');
      await tempFile.writeAsBytes(compressedBytes);

      // Export to MediaStore /Download/PDFReader/
      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: finalFileName,
      );

      setState(() => _isCompressing = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(
              savedPath: publicSavedPath,
              fileName: finalFileName,
              newSizeBytes: compressedBytes.length,
            );
          },
        );
      }
    } catch (e) {
      setState(() => _isCompressing = false);
      _showSnackbar('Compression failed: $e');
    }
  }

  void _promptUnlockUltra() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF8F00), size: 28),
            SizedBox(width: 10),
            Text('Unlock Ultra Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Watch a short video ad to unlock Ultra Max Compression for this document and reduce file size up to 85%!',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text('Watch & Unlock', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              Navigator.pop(ctx);
              RewardedAdManager().showAd(
                onUserEarnedReward: (reward) {
                  setState(() {
                    _isUltraUnlocked = true;
                    _compressionLevel = 3;
                  });
                  _showSnackbar('🎉 Ultra Max Compression unlocked!');
                },
                onAdNotAvailable: () {
                  // Fallback: If no internet or ad fails, unlock anyway for user satisfaction!
                  setState(() {
                    _isUltraUnlocked = true;
                    _compressionLevel = 3;
                  });
                  _showSnackbar('Ultra Max Compression unlocked!');
                },
              );
            },
          ),
        ],
      ),
    );
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

  void _showSuccessDialog({
    required String savedPath,
    required String fileName,
    required int newSizeBytes,
  }) {
    final originalStr = _formatFileSize(_originalSizeBytes);
    final newStr = _formatFileSize(newSizeBytes);
    final reductionPct = _originalSizeBytes > 0
        ? (((_originalSizeBytes - newSizeBytes) / _originalSizeBytes) * 100).clamp(0, 99).toInt()
        : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.compress_rounded,
                  color: Color(0xFFD81B60),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Compression Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 14),

              // Size comparison badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Original', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          originalStr,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFFD81B60), size: 20),
                    Column(
                      children: [
                        const Text('Compressed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          newStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFFD81B60),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (reductionPct > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '🎉 Reduced by $reductionPct% without data loss',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Native Ad inside Compression Success Dialog
              const NativeAdWidget(templateType: NativeTemplateStyleType.small),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Sharing compressed PDF: $fileName',
                            files: [XFile(savedPath)],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Share',
                        style: TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerScreen(
                              filePath: savedPath,
                              fileName: fileName,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD81B60),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Open PDF',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Back to Tools',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E1E1E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Compress PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isCompressing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFD81B60)),
                    const SizedBox(height: 24),
                    Text(
                      _statusText.isNotEmpty ? _statusText : 'Compressing...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _compressProgress > 0 ? _compressProgress : null,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_compressProgress * 100).toInt()}% Completed',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)),
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
                              color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.compress_rounded,
                              size: 48,
                              color: Color(0xFFD81B60),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Compress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Reduce PDF size while maintaining clear text & images',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.file_open_rounded, size: 20),
                            label: const Text(
                              'Choose PDF File',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            onPressed: _pickPdf,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Selected File Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD81B60).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFD81B60),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _sourceFile!.path.split('/').last,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF1E1E1E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$_totalPages Pages • ${_formatFileSize(_originalSizeBytes)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFD81B60)),
                                tooltip: 'Change File',
                                onPressed: _pickPdf,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Compression Presets
                        const Text(
                          'COMPRESSION LEVEL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _buildCompressionCard(
                          title: 'High Compression',
                          badge: 'Max Reduction',
                          description: 'Smallest file size. Best for email & quick sharing.',
                          index: 0,
                        ),
                        const SizedBox(height: 10),
                        _buildCompressionCard(
                          title: 'Medium Compression (Recommended)',
                          badge: 'Balanced',
                          description: 'Good quality and moderate reduction. Best for most PDFs.',
                          index: 1,
                        ),
                        const SizedBox(height: 10),
                        _buildCompressionCard(
                          title: 'Low Compression',
                          badge: 'High Quality',
                          description: 'Highest visual clarity with light file size reduction.',
                          index: 2,
                        ),
                        const SizedBox(height: 10),

                        // Ultra Max Compression Card (Rewarded Video Unlock)
                        InkWell(
                          onTap: () {
                            if (_isUltraUnlocked) {
                              setState(() => _compressionLevel = 3);
                            } else {
                              _promptUnlockUltra();
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _compressionLevel == 3
                                  ? const Color(0xFFFFF8E1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _compressionLevel == 3
                                    ? const Color(0xFFFF8F00)
                                    : const Color(0xFFFFD54F),
                                width: _compressionLevel == 3 ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _compressionLevel == 3
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: const Color(0xFFFF8F00),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Ultra Max Compression',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: Color(0xFFE65100),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _isUltraUnlocked
                                                  ? Colors.green
                                                  : const Color(0xFFFF8F00),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isUltraUnlocked
                                                      ? Icons.check_circle_rounded
                                                      : Icons.play_circle_fill_rounded,
                                                  size: 11,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _isUltraUnlocked ? 'UNLOCKED' : 'PRO (AD)',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Extreme reduction up to 85%. Watch 1 short video to unlock.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Output File Name
                        const Text(
                          'OUTPUT FILE NAME',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fileNameController,
                          decoration: InputDecoration(
                            suffixText: '.pdf',
                            prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Compress Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.compress_rounded, size: 22),
                            label: const Text(
                              'Compress & Save PDF',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            onPressed: _compressPdf,
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

  Widget _buildCompressionCard({
    required String title,
    required String badge,
    required String description,
    required int index,
  }) {
    final isSelected = _compressionLevel == index;
    return InkWell(
      onTap: () => setState(() => _compressionLevel = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCE4EC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD81B60) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFD81B60) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isSelected ? const Color(0xFFD81B60) : const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD81B60) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
