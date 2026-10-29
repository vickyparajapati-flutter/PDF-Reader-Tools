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

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isExtracting = false;
  String _statusText = '';

  // Mode: 0 = Select Pages by Tap, 1 = Custom Range Input
  int _splitMode = 0;
  final Set<int> _selectedPageIndices = {}; // 0-based index

  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
  }

  @override
  void dispose() {
    _rangeController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  // Pick single PDF to split
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
          _selectedPageIndices.clear();
        });

        if (!mounted) return;
        // Safely open PDF (handles encrypted/password protected PDFs)
        final unlocked = await PdfSecurityHelper.openPdfSafely(
          context: context,
          file: file,
        );

        if (unlocked == null) {
          // User cancelled unlock dialog or error occurred
          setState(() {
            _isLoadingPdf = false;
          });
          return;
        }

        final pageCount = unlocked.document.pages.count;
        final cleanBytes = unlocked.bytes;
        unlocked.dispose();

        final baseName = file.path.split('/').last.replaceAll('.pdf', '');
        final uniqueStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        _fileNameController.text = '${baseName}_split_$uniqueStamp';
        _rangeController.text = '1-$pageCount';

        setState(() {
          _sourceFile = file;
          _sourceBytes = cleanBytes;
          _totalPages = pageCount;
          _isLoadingPdf = false;
          // By default select all or first page
          if (pageCount > 0) {
            _selectedPageIndices.add(0);
          }
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

  void _togglePageSelection(int index) {
    setState(() {
      if (_selectedPageIndices.contains(index)) {
        if (_selectedPageIndices.length > 1) {
          _selectedPageIndices.remove(index);
        } else {
          _showSnackbar('At least 1 page must be selected');
        }
      } else {
        _selectedPageIndices.add(index);
      }
    });
  }

  void _selectAllPages(bool select) {
    setState(() {
      _selectedPageIndices.clear();
      if (select) {
        for (int i = 0; i < _totalPages; i++) {
          _selectedPageIndices.add(i);
        }
      } else {
        _selectedPageIndices.add(0); // keep at least 1
      }
    });
  }

  // Parse custom range string like "1-3, 5, 8-10"
  List<int> _parseRangeString(String input) {
    final Set<int> indices = {};
    final parts = input.split(',');

    for (var p in parts) {
      final trimmed = p.trim();
      if (trimmed.contains('-')) {
        final dashParts = trimmed.split('-');
        if (dashParts.length == 2) {
          final start = int.tryParse(dashParts[0].trim());
          final end = int.tryParse(dashParts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              if (i >= 1 && i <= _totalPages) {
                indices.add(i - 1); // 0-based
              }
            }
          }
        }
      } else {
        final single = int.tryParse(trimmed);
        if (single != null && single >= 1 && single <= _totalPages) {
          indices.add(single - 1);
        }
      }
    }

    final sorted = indices.toList()..sort();
    return sorted;
  }

  // 100% Offline Split & Extract Engine
  Future<void> _extractPdfPages() async {
    if (_sourceFile == null || _totalPages == 0) {
      _showSnackbar('Please select a PDF document first.');
      return;
    }

    List<int> pagesToExtract = [];

    if (_splitMode == 0) {
      // Tap selection mode
      pagesToExtract = _selectedPageIndices.toList()..sort();
    } else {
      // Range mode
      pagesToExtract = _parseRangeString(_rangeController.text);
    }

    if (pagesToExtract.isEmpty) {
      _showSnackbar('No valid pages selected for extraction.');
      return;
    }

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'Extracted_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    setState(() {
      _isExtracting = true;
      _statusText = 'Extracting ${pagesToExtract.length} pages...';
    });

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
      final PdfDocument outputDoc = PdfDocument();

      for (int i = 0; i < pagesToExtract.length; i++) {
        final pageIdx = pagesToExtract[i];
        if (pageIdx < sourceDoc.pages.count) {
          final PdfTemplate template = sourceDoc.pages[pageIdx].createTemplate();
          final PdfPage newPage = outputDoc.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.getClientSize(),
          );
        }
      }

      sourceDoc.dispose();

      final List<int> savedBytes = await outputDoc.save();
      outputDoc.dispose();

      // Save to temp then export to Android public MediaStore Downloads
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(savedBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: fileName,
      );

      setState(() => _isExtracting = false);

      if (!mounted) return;
      InterstitialAdManager().showAd(
        onDismissed: () {
          if (!mounted) return;
          _showSuccessDialog(publicSavedPath, fileName, pagesToExtract.length);
        },
      );
    } catch (e) {
      setState(() => _isExtracting = false);
      _showSnackbar('Split failed: $e');
    }
  }

  void _showSuccessDialog(String path, String name, int pageCount) {
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
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'PDF Split Successfully!',
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
                color: Color(0xFF00ACC1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pageCount pages extracted • $sizeStr',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 14),

            // Native Ad inside Success Dialog
            const NativeAdWidget(templateType: NativeTemplateStyleType.small),

            const SizedBox(height: 14),

            // Open in Viewer Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
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
                  'Share Extracted PDF',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(path)],
                      text: 'Extracted PDF created with PDF Reader & Tools',
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
          'Split & Extract Pages',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: _isExtracting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00ACC1)),
                  const SizedBox(height: 20),
                  Text(
                    _statusText.isNotEmpty ? _statusText : 'Extracting pages...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '100% On-Device & Zero Quality Loss',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
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
                              color: const Color(0xFF00ACC1)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_split_rounded,
                              size: 48,
                              color: Color(0xFF00ACC1),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Split',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Choose any PDF document to extract selected pages',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00ACC1),
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
                  : Column(
                      children: [
                        // Selected File Info Card
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00ACC1)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Color(0xFF00ACC1),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        const SizedBox(height: 2),
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
                                        color: Color(0xFF00ACC1),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // File Name Output Box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextField(
                                  controller: _fileNameController,
                                  decoration: const InputDecoration(
                                    icon: Icon(Icons.edit_note_rounded,
                                        color: Color(0xFF00ACC1), size: 20),
                                    hintText: 'Output PDF name...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mode Selector: Tap Select vs Range
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildModeTab(
                                  title: 'Select Pages',
                                  icon: Icons.touch_app_rounded,
                                  isSelected: _splitMode == 0,
                                  onTap: () =>
                                      setState(() => _splitMode = 0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildModeTab(
                                  title: 'Page Range',
                                  icon: Icons.linear_scale_rounded,
                                  isSelected: _splitMode == 1,
                                  onTap: () =>
                                      setState(() => _splitMode = 1),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mode Content
                        Expanded(
                          child: _splitMode == 0
                              ? Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_selectedPageIndices.length} of $_totalPages Pages Selected',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF1E1E1E),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _selectAllPages(true),
                                                child: const Text('Select All'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _selectAllPages(false),
                                                child: const Text('Reset'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.85,
                                        ),
                                        itemCount: _totalPages,
                                        itemBuilder: (context, index) {
                                          final isSelected =
                                              _selectedPageIndices
                                                  .contains(index);
                                          return InkWell(
                                            onTap: () =>
                                                _togglePageSelection(index),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF00ACC1)
                                                      : const Color(0xFFE0E0E0),
                                                  width: isSelected ? 2.5 : 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.03),
                                                    blurRadius: 6,
                                                    offset:
                                                        const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.description_rounded,
                                                          size: 38,
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF00ACC1)
                                                              : const Color(
                                                                  0xFFB0B0B0),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          'Page ${index + 1}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                            color: isSelected
                                                                ? const Color(
                                                                    0xFF00ACC1)
                                                                : const Color(
                                                                    0xFF424242),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Container(
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF00ACC1)
                                                            : Colors.transparent,
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? const Color(
                                                                  0xFF00ACC1)
                                                              : const Color(
                                                                  0xFFB0B0B0),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons.check,
                                                              size: 14,
                                                              color: Colors.white,
                                                            )
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ENTER PAGE RANGE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF8E8E93),
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFF00ACC1),
                                              width: 1.5),
                                        ),
                                        child: TextField(
                                          controller: _rangeController,
                                          onChanged: (val) {
                                            setState(() {});
                                          },
                                          decoration: const InputDecoration(
                                            hintText:
                                                'e.g. 1-4, 6, 8-10',
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Examples:\n• 1-5 (Extracts first 5 pages)\n• 2, 4, 7 (Extracts individual pages)\n• 1-3, 5-8 (Extracts multiple ranges)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        // Bottom Extract Action Button
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color(0xFF00ACC1)
                                      .withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.call_split_rounded,
                                    size: 22),
                                label: Text(
                                  _splitMode == 0
                                      ? 'Extract ${_selectedPageIndices.length} Selected ${_selectedPageIndices.length == 1 ? "Page" : "Pages"}'
                                      : 'Extract Range (${_parseRangeString(_rangeController.text).length} Pages)',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                onPressed: _extractPdfPages,
                              ),
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

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00ACC1).withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00ACC1)
                : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF00ACC1)
                  : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00ACC1)
                    : const Color(0xFF6E6E6E),
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

