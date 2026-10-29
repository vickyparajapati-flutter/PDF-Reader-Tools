import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../models/storage_helper.dart';
import '../models/pdf_security_helper.dart';
import '../models/ad_helper.dart';
import 'widgets/banner_ad_widget.dart';

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isConverting = false;
  double _convertProgress = 0.0;
  String _statusText = '';

  // Options
  // 0: JPG, 1: PNG
  int _imageFormat = 0;
  // 0: High (2x scale), 1: Standard (1.5x), 2: Compact (1x), 3: Ultra HD 4K (3x scale - Rewarded Ad)
  int _quality = 0;
  bool _isUltraHdUnlocked = false;

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
    RewardedAdManager().loadAd(); // Preload Rewarded Video Ad
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
          'PDF to Images',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isConverting
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF29B6F6)),
                    const SizedBox(height: 24),
                    Text(
                      _statusText.isNotEmpty ? _statusText : 'Converting pages...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _convertProgress > 0 ? _convertProgress : null,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF29B6F6)),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_convertProgress * 100).toInt()}% Completed',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
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
                              color: const Color(0xFF29B6F6).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library_rounded,
                              size: 48,
                              color: Color(0xFF29B6F6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Extract Images',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Convert all pages to high quality JPG or PNG pictures',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF29B6F6),
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
                                  color: const Color(0xFF29B6F6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFF0288D1),
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
                                      '$_totalPages Pages detected',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0288D1)),
                                tooltip: 'Change File',
                                onPressed: _pickPdf,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Format Selection
                        const Text(
                          'IMAGE FORMAT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoiceCard(
                                title: 'JPG',
                                subtitle: 'Smaller size, standard',
                                isSelected: _imageFormat == 0,
                                onTap: () => setState(() => _imageFormat = 0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildChoiceCard(
                                title: 'PNG',
                                subtitle: 'Lossless, crisp text',
                                isSelected: _imageFormat == 1,
                                onTap: () => setState(() => _imageFormat = 1),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Resolution Quality
                        const Text(
                          'RESOLUTION / QUALITY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildQualityOption(
                          title: 'High Resolution (HD)',
                          subtitle: 'Best for reading text & details (2x Scale)',
                          index: 0,
                        ),
                        const SizedBox(height: 8),
                        _buildQualityOption(
                          title: 'Standard Quality',
                          subtitle: 'Good balance of quality & file size (1.5x Scale)',
                          index: 1,
                        ),
                        const SizedBox(height: 8),
                        _buildQualityOption(
                          title: 'Compact Quality',
                          subtitle: 'Fast export, low file size (1x Scale)',
                          index: 2,
                        ),
                        const SizedBox(height: 8),

                        // Ultra HD 4K Option (Unlocked with Rewarded Video)
                        InkWell(
                          onTap: () {
                            if (_isUltraHdUnlocked) {
                              setState(() => _quality = 3);
                            } else {
                              _promptUnlockUltraHd();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _quality == 3 ? const Color(0xFFE0F7FA) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _quality == 3 ? const Color(0xFF00ACC1) : const Color(0xFF80DEEA),
                                width: _quality == 3 ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _quality == 3
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: const Color(0xFF00ACC1),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Ultra HD 4K Quality (3x)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFF00838F),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _isUltraHdUnlocked ? Colors.green : const Color(0xFF00ACC1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isUltraHdUnlocked
                                                      ? Icons.check_circle_rounded
                                                      : Icons.play_circle_fill_rounded,
                                                  size: 11,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _isUltraHdUnlocked ? 'UNLOCKED' : 'PRO (AD)',
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
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Maximum 300 DPI clarity. Watch 1 short video to unlock.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF6E6E6E)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Convert Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 22),
                            label: Text(
                              'Convert $_totalPages Pages to Images',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            onPressed: _convertPdfToImages,
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

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE1F5FE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0288D1) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isSelected ? const Color(0xFF0288D1) : const Color(0xFF1E1E1E),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF0288D1), size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _promptUnlockUltraHd() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFF00ACC1), size: 28),
            SizedBox(width: 10),
            Text('Unlock Ultra HD 4K', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Watch a short video ad to unlock Ultra HD 4K (3x Original Scale) export for this document with crystal clear quality!',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ACC1),
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
                    _isUltraHdUnlocked = true;
                    _quality = 3;
                  });
                  _showSnackbar('🎉 Ultra HD 4K Quality unlocked!');
                },
                onAdNotAvailable: () {
                  // Fallback: unlock anyway on network fail
                  setState(() {
                    _isUltraHdUnlocked = true;
                    _quality = 3;
                  });
                  _showSnackbar('Ultra HD 4K Quality unlocked!');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption({
    required String title,
    required String subtitle,
    required int index,
  }) {
    final isSelected = _quality == index;
    return InkWell(
      onTap: () => setState(() => _quality = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE1F5FE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0288D1) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF0288D1) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? const Color(0xFF0288D1) : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _convertPdfToImages() async {
    if (_sourceFile == null || _totalPages == 0) return;

    setState(() {
      _isConverting = true;
      _convertProgress = 0.0;
      _statusText = 'Preparing conversion engine...';
    });

    final List<String> exportedPaths = [];

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final doc = await px.PdfDocument.openData(bytes);

      final ext = _imageFormat == 0 ? 'jpg' : 'png';
      final pxFormat = _imageFormat == 0 ? px.PdfPageImageFormat.jpeg : px.PdfPageImageFormat.png;

      // Scale multiplier
      double scale = 2.0;
      if (_quality == 3) scale = 3.0; // Ultra HD 4K Quality
      if (_quality == 1) scale = 1.5;
      if (_quality == 2) scale = 1.0;

      final baseName = _sourceFile!.path.split('/').last.replaceAll('.pdf', '');
      final timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

      for (int i = 1; i <= doc.pagesCount; i++) {
        if (!mounted) break;

        setState(() {
          _convertProgress = (i - 1) / doc.pagesCount;
          _statusText = 'Rendering page $i of ${doc.pagesCount}...';
        });

        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pxFormat,
        );
        await page.close();

        if (pageImage != null) {
          final tempDir = await getTemporaryDirectory();
          final imgFileName = '${baseName}_p${i}_$timeStamp.$ext';
          final tempImgFile = File('${tempDir.path}/$imgFileName');
          await tempImgFile.writeAsBytes(pageImage.bytes);

          // Save to Android public Pictures/PDFReader via MediaStore
          final publicSaved = await StorageHelper.saveImageToPublicPictures(
            tempFile: tempImgFile,
            fileName: imgFileName,
          );
          exportedPaths.add(publicSaved);
        }
      }

      await doc.close();

      setState(() => _isConverting = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(exportedPaths);
          },
        );
      }
    } catch (e) {
      setState(() => _isConverting = false);
      _showSnackbar('Conversion failed: $e');
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

  void _showSuccessDialog(List<String> paths) {
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
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0288D1),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Conversion Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${paths.length} Images Saved to Gallery',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0288D1),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Folder: Pictures/PDFReader',
                style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              if (paths.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(paths.first),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (paths.isNotEmpty) {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'Exported ${paths.length} images from PDF',
                              files: paths.map((p) => XFile(p)).toList(),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Share All',
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
                        if (paths.isNotEmpty) {
                          OpenFilex.open(paths.first);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0288D1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View in Gallery',
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
}

