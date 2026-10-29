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

class ReorderPagesScreen extends StatefulWidget {
  const ReorderPagesScreen({super.key});

  @override
  State<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends State<ReorderPagesScreen> {
  File? _sourceFile;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  bool _isLoadingPdf = false;
  bool _isSaving = false;
  String _statusText = '';

  // List of page indices in user order (0-based)
  List<int> _pageOrder = [];

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
          _pageOrder.clear();
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
        _fileNameController.text = '${baseName}_reordered_$uniqueStamp';

        setState(() {
          _sourceFile = file;
          _sourceBytes = cleanBytes;
          _totalPages = pageCount;
          _pageOrder = List.generate(pageCount, (index) => index);
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

  void _removePage(int listIndex) {
    if (_pageOrder.length <= 1) {
      _showSnackbar('PDF must contain at least 1 page');
      return;
    }
    setState(() {
      _pageOrder.removeAt(listIndex);
    });
  }

  void _resetOrder() {
    setState(() {
      _pageOrder = List.generate(_totalPages, (index) => index);
    });
  }

  Future<void> _saveReorderedPdf() async {
    if (_sourceFile == null || _pageOrder.isEmpty) {
      _showSnackbar('No pages to save');
      return;
    }

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'Reordered_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    setState(() {
      _isSaving = true;
      _statusText = 'Building reordered PDF...';
    });

    try {
      final bytes = _sourceBytes ?? await _sourceFile!.readAsBytes();
      final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
      final PdfDocument outputDoc = PdfDocument();

      for (int i = 0; i < _pageOrder.length; i++) {
        final originalPageIdx = _pageOrder[i];
        if (originalPageIdx < sourceDoc.pages.count) {
          final PdfTemplate template = sourceDoc.pages[originalPageIdx].createTemplate();
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

      setState(() => _isSaving = false);

      if (!mounted) return;
      InterstitialAdManager().showAd(
        onDismissed: () {
          if (!mounted) return;
          _showSuccessDialog(publicSavedPath, fileName, _pageOrder.length);
        },
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackbar('Failed to reorder PDF: $e');
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
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF5C6BC0),
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'PDF Reordered Successfully!',
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
                color: Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pageCount pages • $sizeStr',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.folder_rounded, size: 20, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved to Download/PDFReader',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF495057),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Sharing reordered PDF: $name',
                        files: [XFile(path)],
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
                          filePath: path,
                          fileName: name,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
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
          const SizedBox(height: 6),
          Center(
            child: TextButton(
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E1E1E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reorder Pages',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_sourceFile != null && !_isSaving)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5C6BC0)),
              tooltip: 'Reset Order',
              onPressed: _resetOrder,
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF5C6BC0)),
                  const SizedBox(height: 20),
                  Text(
                    _statusText.isNotEmpty ? _statusText : 'Processing...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : _isLoadingPdf
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5C6BC0)),
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
                              color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.reorder_rounded,
                              size: 48,
                              color: Color(0xFF5C6BC0),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Select PDF to Reorder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Drag and rearrange pages in any order you like',
                            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5C6BC0),
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
                        // Header info
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Color(0xFF5C6BC0),
                                      size: 22,
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
                                          '${_pageOrder.length} Pages active • Drag items to reorder',
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
                                        color: Color(0xFF5C6BC0),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _fileNameController,
                                decoration: InputDecoration(
                                  labelText: 'Output File Name',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  suffixText: '.pdf',
                                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FA),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tip Banner
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFEDE7F6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF5C6BC0)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Long press & drag cards to reorder. Tap ✕ to remove.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3949AB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reorderable Grid
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pageOrder.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = _pageOrder.removeAt(oldIndex);
                                _pageOrder.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final originalPage = _pageOrder[index] + 1;
                              return Card(
                                key: ValueKey('page_${_pageOrder[index]}'),
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5C6BC0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Page $originalPage (Original)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Will be placed at position ${index + 1}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                                        tooltip: 'Remove Page',
                                        onPressed: () => _removePage(index),
                                      ),
                                      const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Bottom Action Bar
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
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C6BC0),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.check_rounded, size: 20),
                                label: Text(
                                  'Save Reordered PDF (${_pageOrder.length} Pages)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: _pageOrder.isNotEmpty ? _saveReorderedPdf : null,
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
}
