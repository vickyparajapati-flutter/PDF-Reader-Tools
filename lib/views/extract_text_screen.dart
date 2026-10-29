import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_security_helper.dart';
import 'widgets/banner_ad_widget.dart';

class ExtractTextScreen extends StatefulWidget {
  const ExtractTextScreen({super.key});

  @override
  State<ExtractTextScreen> createState() => _ExtractTextScreenState();
}

class _ExtractTextScreenState extends State<ExtractTextScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isExtracting = false;
  String _extractedText = '';

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
          'Extract Text',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_extractedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Color(0xFF7E57C2)),
              tooltip: 'Copy All Text',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Color(0xFF7E57C2)),
              tooltip: 'Share Text',
              onPressed: _shareText,
            ),
          ],
        ],
      ),
      body: _isExtracting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7E57C2)),
                  SizedBox(height: 20),
                  Text(
                    'Extracting text streams...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7E57C2)),
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
                              color: const Color(0xFF7E57C2).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              size: 48,
                              color: Color(0xFF7E57C2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Extract Text from PDF',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pull readable text from PDF documents to copy or share',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E57C2),
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
                        // Selected File Card
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFF7E57C2),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _sourceFile!.path.split('/').last,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF1E1E1E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
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
                              TextButton(
                                onPressed: _pickPdf,
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Color(0xFF7E57C2),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Text Content Area
                        Expanded(
                          child: _extractedText.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'No readable text extracted',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'This PDF may consist purely of scanned images without text streams.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      _extractedText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ),
                        ),

                        // Bottom Actions
                        if (_extractedText.isNotEmpty)
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _copyToClipboard,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        side: const BorderSide(color: Color(0xFF7E57C2)),
                                      ),
                                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF7E57C2), size: 18),
                                      label: const Text(
                                        'Copy All',
                                        style: TextStyle(
                                          color: Color(0xFF7E57C2),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _shareText,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7E57C2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.share_rounded, size: 18),
                                      label: const Text(
                                        'Share Text',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
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
          _extractedText = '';
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

        // Trigger extraction immediately
        _extractTextFromPdf();
      }
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      _showSnackbar('Error reading PDF: $e');
    }
  }

  Future<void> _extractTextFromPdf() async {
    if (_sourceFile == null) return;

    setState(() => _isExtracting = true);

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final textExtractor = PdfTextExtractor(doc);

      // Extract all text
      final extracted = textExtractor.extractText();
      doc.dispose();

      setState(() {
        _extractedText = extracted.trim();
        _isExtracting = false;
      });

      if (_extractedText.isEmpty) {
        _showSnackbar('No readable text found in this PDF.');
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      _showSnackbar('Extraction failed: $e');
    }
  }

  void _copyToClipboard() {
    if (_extractedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText));
    _showSnackbar('Text copied to clipboard!');
  }

  void _shareText() {
    if (_extractedText.isEmpty) return;
    SharePlus.instance.share(
      ShareParams(
        text: _extractedText,
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
}
