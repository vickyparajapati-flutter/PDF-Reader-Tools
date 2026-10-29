import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/ad_helper.dart';
import 'widgets/banner_ad_widget.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  int _actualPageNumber = 1;
  int _allPagesCount = 0;
  bool _isNightMode = false;
  bool _showControls = true;
  bool _isLoading = true;
  bool _isPasswordProtected = false;
  String? _errorMessage;

  final TextEditingController _passwordInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd(); // Preload ad for exit
    _checkAndInitPdf();
  }

  @override
  void dispose() {
    _passwordInputController.dispose();
    if (_errorMessage == null && !_isPasswordProtected) {
      _pdfController.dispose();
    }
    super.dispose();
  }

  Future<void> _checkAndInitPdf({String? password}) async {
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      setState(() {
        _errorMessage = 'File does not exist or cannot be accessed.';
        _isLoading = false;
      });
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      // First verify with Syncfusion engine if it is encrypted
      try {
        final sfDoc = sf.PdfDocument(inputBytes: bytes, password: password);
        sfDoc.dispose();
      } catch (e) {
        // If password is required or incorrect
        setState(() {
          _isPasswordProtected = true;
          _isLoading = false;
        });
        _showPasswordDialog();
        return;
      }

      // If document is unlocked or password is correct
      if (password != null) {
        // Decrypt into an unencrypted in-memory document for viewing
        final sfDoc = sf.PdfDocument(inputBytes: bytes, password: password);
        final unencryptedDoc = sf.PdfDocument();

        for (int i = 0; i < sfDoc.pages.count; i++) {
          final template = sfDoc.pages[i].createTemplate();
          final page = unencryptedDoc.pages.add();
          page.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            page.getClientSize(),
          );
        }

        sfDoc.dispose();
        final unencryptedBytes = await unencryptedDoc.save();
        unencryptedDoc.dispose();

        _pdfController = PdfControllerPinch(
          document: PdfDocument.openData(Uint8List.fromList(unencryptedBytes)),
        );
      } else {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(widget.filePath),
        );
      }

      setState(() {
        _isPasswordProtected = false;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  void _showPasswordDialog() {
    _passwordInputController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFE5252A)),
            SizedBox(width: 8),
            Text('Password Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This document is protected. Enter the password to open it:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordInputController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter document password',
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit viewer
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5252A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final pwd = _passwordInputController.text;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              _checkAndInitPdf(password: pwd);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isNightMode ? 'Night reading mode ON' : 'Day mode ON'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareFile() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.filePath)],
          text: 'Sharing ${widget.fileName}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share file: $e')),
      );
    }
  }

  Future<void> _printDocument() async {
    try {
      final fileBytes = await File(widget.filePath).readAsBytes();
      await Printing.layoutPdf(
        name: widget.fileName,
        onLayout: (format) async => fileBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e')),
      );
    }
  }

  void _jumpToPageDialog() {
    final textController = TextEditingController(text: '$_actualPageNumber');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Go to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter page number (1 - $_allPagesCount):',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5252A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final target = int.tryParse(textController.text.trim());
              if (target != null && target >= 1 && target <= _allPagesCount) {
                _pdfController.animateToPage(
                  pageNumber: target,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid page (1 - $_allPagesCount)')),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _handleBackPress() {
    InterstitialAdManager().showAd(
      onDismissed: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isNightMode ? const Color(0xFF121212) : const Color(0xFFEFEFEF);
    final appBarColor = _isNightMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isNightMode ? Colors.white : const Color(0xFF1E1E1E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // PDF Rendering Engine with Touch Handling
          GestureDetector(
            onTap: _toggleControls,
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFE5252A)),
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isLoading || _isPasswordProtected
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE5252A)),
                      )
                    : ColorFiltered(
                        colorFilter: _isNightMode
                            ? const ColorFilter.matrix([
                                -0.85, 0, 0, 0, 240,
                                0, -0.85, 0, 0, 240,
                                0, 0, -0.75, 0, 230,
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              ),
                        child: PdfViewPinch(
                          controller: _pdfController,
                          onDocumentLoaded: (doc) {
                            setState(() {
                              _allPagesCount = doc.pagesCount;
                            });
                          },
                          onPageChanged: (page) {
                            setState(() {
                              _actualPageNumber = page;
                            });
                          },
                        ),
                      ),
          ),

          // Top Modern App Bar with Controls (Animated)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 8,
                left: 8,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: appBarColor.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                    onPressed: _handleBackPress,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (_allPagesCount > 0)
                          Text(
                            'Page $_actualPageNumber of $_allPagesCount',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isNightMode ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                      color: _isNightMode ? const Color(0xFFFFD700) : textColor,
                    ),
                    tooltip: 'Night Mode',
                    onPressed: _toggleNightMode,
                  ),
                  IconButton(
                    icon: Icon(Icons.print_outlined, color: textColor),
                    tooltip: 'Print',
                    onPressed: _printDocument,
                  ),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: textColor),
                    tooltip: 'Share',
                    onPressed: _shareFile,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Quick Page Jump Floating Capsule
          if (_allPagesCount > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              bottom: _showControls ? 70 : -80,
              left: 40,
              right: 40,
              child: Center(
                child: GestureDetector(
                  onTap: _jumpToPageDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_vert_rounded,
                          color: Color(0xFFE5252A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_actualPageNumber / $_allPagesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Jump',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Sticky Banner Ad in PDF Viewer
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: BannerAdWidget(),
            ),
          ),
        ],
      ),
    ),
  );
}
}
