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

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<File> _selectedFiles = [];
  final Map<String, Uint8List> _unlockedBytesMap = {};
  bool _isMerging = false;
  String _mergeStatus = '';
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd(); // Preload ad when screen opens
    _fileNameController.text =
        'Merged_Doc_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isNotEmpty) {
        for (var p in result) {
          if (p.path != null) {
            final file = File(p.path!);
            // Avoid duplicates
            if (!_selectedFiles.any((f) => f.path == file.path)) {
              if (!mounted) return;
              // Check & verify file (handles password-protected files)
              final unlocked = await PdfSecurityHelper.openPdfSafely(
                context: context,
                file: file,
              );

              if (unlocked != null) {
                // Keep the unlocked clean bytes so we NEVER prompt again during merge
                _unlockedBytesMap[file.path] = unlocked.bytes;
                unlocked.dispose();
                setState(() {
                  _selectedFiles.add(file);
                });
              }
            }
          }
        }
      }
    } catch (e) {
      _showSnackbar('Error picking PDF files: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      final removed = _selectedFiles.removeAt(index);
      _unlockedBytesMap.remove(removed.path);
    });
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedFiles.removeAt(oldIndex);
      _selectedFiles.insert(newIndex, item);
    });
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // 100% Offline & High-Performance PDF Merge Engine
  Future<void> _mergePdfs() async {
    if (_selectedFiles.length < 2) {
      _showSnackbar('Please select at least 2 PDF files to merge.');
      return;
    }

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'Merged_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    setState(() {
      _isMerging = true;
      _mergeStatus = 'Preparing document merger...';
    });

    try {
      // Create a new target PDF document
      final PdfDocument finalPdf = PdfDocument();
      int totalPagesMerged = 0;

      for (int i = 0; i < _selectedFiles.length; i++) {
        if (!mounted) return;
        final file = _selectedFiles[i];
        final fileNameShort = file.path.split('/').last;

        setState(() {
          _mergeStatus =
              'Appending ${i + 1} of ${_selectedFiles.length} ($fileNameShort)...';
        });

        // If we already unlocked this file during picking, use its cached bytes directly
        final bytes = _unlockedBytesMap[file.path] ?? await file.readAsBytes();
        if (!mounted) return;
        final unlocked = await PdfSecurityHelper.openPdfBytesSafely(
          context: context,
          bytes: bytes,
          fileName: fileNameShort,
          filePathKey: file.path,
        );

        if (unlocked == null) {
          throw Exception('Unable to open $fileNameShort');
        }

        final PdfDocument sourcePdf = unlocked.document;

        // Import all pages into the destination document
        for (int p = 0; p < sourcePdf.pages.count; p++) {
          final PdfTemplate template = sourcePdf.pages[p].createTemplate();
          final PdfPage newPage = finalPdf.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            newPage.getClientSize(),
          );
          totalPagesMerged++;
        }

        sourcePdf.dispose();
      }

      setState(() {
        _mergeStatus = 'Finalizing and saving merged PDF...';
      });

      final List<int> savedBytes = await finalPdf.save();
      finalPdf.dispose();

      // Save merged file into app temp then export to Android public MediaStore Downloads
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(savedBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: fileName,
      );

      setState(() => _isMerging = false);

      if (!mounted) return;
      InterstitialAdManager().showAd(
        onDismissed: () {
          if (!mounted) return;
          _showSuccessDialog(publicSavedPath, fileName, totalPagesMerged);
        },
      );
    } catch (e) {
      setState(() => _isMerging = false);
      _showSnackbar('Merge failed: $e');
    }
  }

  void _showSuccessDialog(String path, String name, int pageCount) {
    final file = File(path);
    final sizeInBytes = file.existsSync() ? file.lengthSync() : 0;
    final sizeStr = _formatFileSize(sizeInBytes);

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
              'PDF Merged Successfully!',
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
                color: Color(0xFF43A047),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_selectedFiles.length} files combined • $pageCount pages • $sizeStr',
              textAlign: TextAlign.center,
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
                  backgroundColor: const Color(0xFF43A047),
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
                  'Share Merged PDF',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(path)],
                      text: 'Merged PDF created with PDF Reader & Tools',
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
          'Merge PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
      ),
      body: _isMerging
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF43A047)),
                  const SizedBox(height: 20),
                  Text(
                    _mergeStatus.isNotEmpty ? _mergeStatus : 'Merging PDFs...',
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
          : Column(
              children: [
                // File Name Box
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _fileNameController,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.edit_note_rounded,
                            color: Color(0xFF43A047)),
                        hintText: 'Enter merged PDF file name...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                // Selected Files Area
                Expanded(
                  child: _selectedFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43A047)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.call_merge_rounded,
                                  size: 48,
                                  color: Color(0xFF43A047),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Select PDFs to Combine',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select 2 or more PDF documents to merge into one',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF8E8E93)),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF43A047),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 13),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 22),
                                label: const Text(
                                  'Choose PDF Files',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: _pickPdfFiles,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_selectedFiles.length} Files Selected • Drag to change sequence',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickPdfFiles,
                                    icon: const Icon(Icons.add_rounded,
                                        size: 18, color: Color(0xFF43A047)),
                                    label: const Text(
                                      'Add More',
                                      style: TextStyle(
                                        color: Color(0xFF43A047),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _selectedFiles.length,
                                onReorder: _reorderFiles,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
                                  final name = file.path.split('/').last;
                                  final sizeStr = file.existsSync()
                                      ? _formatFileSize(file.lengthSync())
                                      : 'Unknown size';

                                  return Container(
                                    key: ValueKey(file.path),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF43A047)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Color(0xFF43A047),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      subtitle: Text(
                                        sizeStr,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8E8E93)),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFE53935)),
                                            onPressed: () => _removeFile(index),
                                          ),
                                          const Icon(Icons.drag_handle_rounded,
                                              color: Color(0xFFB0B0B0)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                // Bottom Action Bar
                if (_selectedFiles.isNotEmpty)
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
                            backgroundColor: const Color(0xFF43A047),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF43A047)
                                .withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon:
                              const Icon(Icons.call_merge_rounded, size: 22),
                          label: Text(
                            'Merge ${_selectedFiles.length} Files Now',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _mergePdfs,
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
