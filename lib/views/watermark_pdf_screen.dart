import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
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

class WatermarkPdfScreen extends StatefulWidget {
  const WatermarkPdfScreen({super.key});

  @override
  State<WatermarkPdfScreen> createState() => _WatermarkPdfScreenState();
}

class _WatermarkPdfScreenState extends State<WatermarkPdfScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isApplying = false;

  final TextEditingController _watermarkTextController =
      TextEditingController(text: 'CONFIDENTIAL');
  final TextEditingController _fileNameController = TextEditingController();

  // Watermark Options
  double _opacity = 0.3; // 0.1 to 0.9
  final double _fontSize = 42; // 20 to 70
  int _rotationAngle = 45; // 0, 45, -45
  Color _watermarkColor = Colors.red;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.grey,
    Colors.blue,
    Colors.green,
    Colors.black,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
  }

  @override
  void dispose() {
    _watermarkTextController.dispose();
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
        _fileNameController.text = '${baseName}_watermark_$uniqueStamp';

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

  Future<void> _applyWatermark() async {
    if (_sourceFile == null || _totalPages == 0) return;

    final watermarkText = _watermarkTextController.text.trim();
    if (watermarkText.isEmpty) {
      _showSnackbar('Please enter watermark text');
      return;
    }

    final outName = _fileNameController.text.trim();
    if (outName.isEmpty) {
      _showSnackbar('Please enter output file name');
      return;
    }

    setState(() => _isApplying = true);

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      // Setup Font and Color
      final font = PdfStandardFont(PdfFontFamily.helvetica, _fontSize, style: PdfFontStyle.bold);
      final pdfColor = PdfColor(
        _watermarkColor.r.toInt(),
        _watermarkColor.g.toInt(),
        _watermarkColor.b.toInt(),
      );
      final brush = PdfSolidBrush(pdfColor);

      final textSize = font.measureString(watermarkText);

      // Stamp every page
      for (int i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final pageSize = page.getClientSize();
        final graphics = page.graphics;

        // Save current graphics state
        final state = graphics.save();

        // Apply transparency / opacity
        graphics.setTransparency(_opacity);

        // Center position
        final centerX = pageSize.width / 2;
        final centerY = pageSize.height / 2;

        graphics.translateTransform(centerX, centerY);
        if (_rotationAngle != 0) {
          graphics.rotateTransform(_rotationAngle.toDouble());
        }

        // Draw centered text
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(
            -textSize.width / 2,
            -textSize.height / 2,
            textSize.width,
            textSize.height,
          ),
        );

        // Restore graphics state for clean layout
        graphics.restore(state);
      }

      final savedBytes = doc.saveSync();
      doc.dispose();

      // Save via native MediaStore to /Download/PDFReader/
      final tempDir = await getTemporaryDirectory();
      final finalFileName = outName.toLowerCase().endsWith('.pdf') ? outName : '$outName.pdf';
      final tempFile = File('${tempDir.path}/$finalFileName');
      await tempFile.writeAsBytes(savedBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: finalFileName,
      );

      setState(() => _isApplying = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(publicSavedPath, finalFileName);
          },
        );
      }
    } catch (e) {
      setState(() => _isApplying = false);
      _showSnackbar('Watermark failed: $e');
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

  void _showSuccessDialog(String savedPath, String fileName) {
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
                  color: const Color(0xFFFB8C00).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFFB8C00),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Watermark Added!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFB8C00),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_totalPages pages stamped • Saved to Download/PDFReader',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Native Ad inside Watermark Success Dialog
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
                            text: 'Sharing watermarked PDF: $fileName',
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
                        backgroundColor: const Color(0xFFFB8C00),
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
          'Watermark PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isApplying
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFB8C00)),
                  SizedBox(height: 20),
                  Text(
                    'Stamping watermark on all pages...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFB8C00)),
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
                              color: const Color(0xFFFB8C00).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.branding_watermark_rounded,
                              size: 48,
                              color: Color(0xFFFB8C00),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Watermark',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Stamp text watermark across all pages for copyright protection',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFB8C00),
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
                                  color: const Color(0xFFFB8C00).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFFB8C00),
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
                                icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFFB8C00)),
                                tooltip: 'Change File',
                                onPressed: _pickPdf,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Live Preview Box
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Positioned(
                                top: 8,
                                left: 12,
                                child: Text(
                                  'PREVIEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Transform.rotate(
                                angle: _rotationAngle * (math.pi / 180),
                                child: Opacity(
                                  opacity: _opacity,
                                  child: Text(
                                    _watermarkTextController.text.isNotEmpty
                                        ? _watermarkTextController.text
                                        : 'WATERMARK',
                                    style: TextStyle(
                                      fontSize: _fontSize / 1.6,
                                      fontWeight: FontWeight.w900,
                                      color: _watermarkColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Watermark Text Input
                        const Text(
                          'WATERMARK TEXT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _watermarkTextController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'e.g. CONFIDENTIAL, DRAFT, COPY',
                            prefixIcon: const Icon(Icons.text_fields_rounded, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFB8C00), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Color selection
                        const Text(
                          'STAMP COLOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _availableColors.map((color) {
                            final isSelected = _watermarkColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _watermarkColor = color),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black87 : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Opacity slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'OPACITY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                            Text(
                              '${(_opacity * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                        Slider(
                          value: _opacity,
                          min: 0.1,
                          max: 0.8,
                          activeColor: const Color(0xFFFB8C00),
                          onChanged: (val) => setState(() => _opacity = val),
                        ),

                        // Rotation Angle
                        const Text(
                          'ROTATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildRotationButton('Diagonal (45°)', 45),
                            const SizedBox(width: 10),
                            _buildRotationButton('Horizontal (0°)', 0),
                            const SizedBox(width: 10),
                            _buildRotationButton('Reverse (-45°)', -45),
                          ],
                        ),

                        const SizedBox(height: 20),

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
                              borderSide: const BorderSide(color: Color(0xFFFB8C00), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Apply Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFB8C00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 22),
                            label: const Text(
                              'Add Watermark & Save PDF',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            onPressed: _applyWatermark,
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

  Widget _buildRotationButton(String title, int angle) {
    final isSelected = _rotationAngle == angle;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _rotationAngle = angle),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF3E0) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFB8C00) : Colors.grey.shade300,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? const Color(0xFFFB8C00) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
