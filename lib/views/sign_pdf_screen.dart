import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as px;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/storage_helper.dart';
import '../models/pdf_security_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';

class SignPdfScreen extends StatefulWidget {
  const SignPdfScreen({super.key});

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends State<SignPdfScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  int _currentPageIndex = 0; // 0-based
  bool _isLoadingPdf = false;
  bool _isSaving = false;

  // Rendered page image for preview
  Uint8List? _currentPageImageBytes;
  double _pageWidth = 0;
  double _pageHeight = 0;

  // Drawn Signature
  Uint8List? _signaturePngBytes;

  // Placed Signature position and size on the preview
  Offset _signPosition = const Offset(50, 200);
  final double _signWidth = 140;
  final double _signHeight = 65;

  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
  }

  @override
  void dispose() {
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
          _currentPageIndex = 0;
          _signaturePngBytes = null;
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
        _fileNameController.text = '${baseName}_signed_$uniqueStamp';

        _sourceFile = file;
        _sourceBytes = cleanBytes;
        _totalPages = pageCount;

        // Render first page preview
        await _renderCurrentPagePreview();

        setState(() {
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      _showSnackbar('Error reading PDF: $e');
    }
  }

  Future<void> _renderCurrentPagePreview() async {
    if (_sourceBytes == null) return;
    try {
      final doc = await px.PdfDocument.openData(_sourceBytes!);
      final page = await doc.getPage(_currentPageIndex + 1);
      final render = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: px.PdfPageImageFormat.jpeg,
      );
      _pageWidth = page.width;
      _pageHeight = page.height;
      await page.close();
      await doc.close();

      if (render != null) {
        setState(() {
          _currentPageImageBytes = render.bytes;
        });
      }
    } catch (e) {
      _showSnackbar('Failed to preview page: $e');
    }
  }

  void _openSignaturePad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SignaturePadSheet(
        onSigned: (pngBytes) {
          setState(() {
            _signaturePngBytes = pngBytes;
          });
        },
      ),
    );
  }

  Future<void> _saveSignedPdf() async {
    if (_sourceFile == null || _totalPages == 0) return;
    if (_signaturePngBytes == null) {
      _showSnackbar('Please add your signature first');
      return;
    }

    final outName = _fileNameController.text.trim();
    if (outName.isEmpty) {
      _showSnackbar('Please enter output file name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      final targetPage = doc.pages[_currentPageIndex];
      final targetPageSize = targetPage.getClientSize();

      if (!mounted) return;
      // Normalize coordinates
      // The preview container width is bounded by screen width - 32 padding
      final renderBoxWidth = MediaQuery.of(context).size.width - 32;
      final scaleFactor = targetPageSize.width / renderBoxWidth;

      final pdfX = _signPosition.dx * scaleFactor;
      final pdfY = _signPosition.dy * scaleFactor;
      final pdfW = _signWidth * scaleFactor;
      final pdfH = _signHeight * scaleFactor;

      final signImage = PdfBitmap(_signaturePngBytes!);
      targetPage.graphics.drawImage(
        signImage,
        Rect.fromLTWH(pdfX, pdfY, pdfW, pdfH),
      );

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

      setState(() => _isSaving = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(publicSavedPath, finalFileName);
          },
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackbar('Failed to sign PDF: $e');
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
                  color: const Color(0xFF673AB7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.draw_rounded,
                  color: Color(0xFF673AB7),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Document Signed!',
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
                  color: Color(0xFF673AB7),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Signature applied • Saved to Download/PDFReader',
                style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
                            text: 'Sharing signed document: $fileName',
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
                        backgroundColor: const Color(0xFF673AB7),
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
          'Sign PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF673AB7)),
                  SizedBox(height: 20),
                  Text(
                    'Embedding signature onto PDF...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF673AB7)),
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
                              color: const Color(0xFF673AB7).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.draw_rounded,
                              size: 48,
                              color: Color(0xFF673AB7),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Sign',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Draw your signature and place it anywhere on any page',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF673AB7),
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
                  : Column(
                      children: [
                        // Page Selector Top Bar
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                                onPressed: _currentPageIndex > 0
                                    ? () async {
                                        setState(() {
                                          _currentPageIndex--;
                                          _currentPageImageBytes = null;
                                        });
                                        await _renderCurrentPagePreview();
                                      }
                                    : null,
                              ),
                              Text(
                                'Page ${_currentPageIndex + 1} of $_totalPages',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                                onPressed: _currentPageIndex < _totalPages - 1
                                    ? () async {
                                        setState(() {
                                          _currentPageIndex++;
                                          _currentPageImageBytes = null;
                                        });
                                        await _renderCurrentPagePreview();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        // Document Preview with Draggable Signature
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: _currentPageImageBytes == null
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(40),
                                      child: CircularProgressIndicator(color: Color(0xFF673AB7)),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final previewWidth = constraints.maxWidth;
                                      final aspectRatio = _pageWidth > 0 ? _pageHeight / _pageWidth : 1.414;
                                      final previewHeight = previewWidth * aspectRatio;

                                      return Container(
                                        width: previewWidth,
                                        height: previewHeight,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Page Image
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.memory(
                                                  _currentPageImageBytes!,
                                                  fit: BoxFit.fill,
                                                ),
                                              ),
                                            ),

                                            // Draggable Signature Overlay
                                            if (_signaturePngBytes != null)
                                              Positioned(
                                                left: _signPosition.dx,
                                                top: _signPosition.dy,
                                                child: GestureDetector(
                                                  onPanUpdate: (details) {
                                                    setState(() {
                                                      double newX = _signPosition.dx + details.delta.dx;
                                                      double newY = _signPosition.dy + details.delta.dy;

                                                      newX = newX.clamp(0.0, previewWidth - _signWidth);
                                                      newY = newY.clamp(0.0, previewHeight - _signHeight);

                                                      _signPosition = Offset(newX, newY);
                                                    });
                                                  },
                                                  child: Container(
                                                    width: _signWidth,
                                                    height: _signHeight,
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: const Color(0xFF673AB7),
                                                        width: 1.5,
                                                      ),
                                                      borderRadius: BorderRadius.circular(6),
                                                      color: Colors.white.withValues(alpha: 0.3),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: Image.memory(
                                                            _signaturePngBytes!,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Positioned(
                                                          right: 0,
                                                          top: 0,
                                                          child: GestureDetector(
                                                            onTap: () {
                                                              setState(() {
                                                                _signaturePngBytes = null;
                                                              });
                                                            },
                                                            child: Container(
                                                              decoration: const BoxDecoration(
                                                                color: Colors.red,
                                                                shape: BoxShape.circle,
                                                              ),
                                                              padding: const EdgeInsets.all(2),
                                                              child: const Icon(
                                                                Icons.close,
                                                                size: 12,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),

                        // Bottom Control Panel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_signaturePngBytes == null)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF673AB7),
                                        side: const BorderSide(color: Color(0xFF673AB7), width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.draw_rounded, size: 20),
                                      label: const Text(
                                        'Create Signature',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      onPressed: _openSignaturePad,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.grey.shade800,
                                            side: BorderSide(color: Colors.grey.shade300),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: const Icon(Icons.edit_rounded, size: 18),
                                          label: const Text('Change Sign', style: TextStyle(fontSize: 13)),
                                          onPressed: _openSignaturePad,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF673AB7),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            elevation: 2,
                                          ),
                                          icon: const Icon(Icons.check_rounded, size: 20),
                                          label: const Text(
                                            'Save Signed PDF',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          onPressed: _saveSignedPdf,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
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

/// Bottom Sheet Signature Pad for drawing with finger
class _SignaturePadSheet extends StatefulWidget {
  final ValueChanged<Uint8List> onSigned;

  const _SignaturePadSheet({required this.onSigned});

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<Offset?> _points = [];
  Color _strokeColor = Colors.black;

  final List<Color> _colors = [
    Colors.black,
    Colors.blue.shade900,
    Colors.red.shade900,
  ];

  Future<void> _captureSignature() async {
    if (_points.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(320, 160);

    final paint = Paint()
      ..color = _strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      widget.onSigned(byteData.buffer.asUint8List());
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Draw Your Signature',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign with your finger on the canvas below',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),

          // Signature Drawing Box
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                final localPos = details.localPosition;
                setState(() {
                  _points.add(localPos);
                });
              },
              onPanEnd: (_) => _points.add(null),
              child: CustomPaint(
                painter: _SignPainter(points: _points, color: _strokeColor),
                size: Size.infinite,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Color & Clear Bar
          Row(
            children: [
              const Text('Ink Color:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 8),
              ..._colors.map((color) {
                final isSelected = _strokeColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _strokeColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF673AB7) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _points.clear()),
                icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.red),
                label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF673AB7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _points.isNotEmpty ? _captureSignature : null,
              child: const Text('Apply Signature', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;

  _SignPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignPainter oldDelegate) => true;
}
