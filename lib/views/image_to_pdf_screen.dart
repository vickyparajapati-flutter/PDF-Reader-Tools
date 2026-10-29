import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/storage_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/native_ad_widget.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isConverting = false;
  String _conversionStatus = '';

  // Conversion options
  String _pageOrientation = 'Portrait'; // 'Portrait' or 'Landscape'
  String _qualityMode = 'High'; // 'Original', 'High', 'Medium', 'Low'
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
    _fileNameController.text =
        'Scanned_Doc_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  // Pick images from Gallery (Original resolution preserved)
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      _showSnackbar('Error picking images: $e');
    }
  }

  // Capture photo from Camera (Original resolution preserved)
  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      _showSnackbar('Error capturing photo: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
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

  // Quality parameters mapping
  int _getQualityValue() {
    switch (_qualityMode) {
      case 'Original':
        return 100;
      case 'High':
        return 92;
      case 'Medium':
        return 75;
      case 'Low':
        return 50;
      default:
        return 90;
    }
  }

  int _getMaxDimension() {
    switch (_qualityMode) {
      case 'Original':
        return 4096; // 4K+ crystal clear
      case 'High':
        return 2560; // 2K ultra sharp
      case 'Medium':
        return 1600; // Balanced
      case 'Low':
        return 1080; // Compressed small size
      default:
        return 2560;
    }
  }

  // Core PDF Generation Engine
  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) {
      _showSnackbar('Please add at least 1 image.');
      return;
    }

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = 'Document_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    setState(() {
      _isConverting = true;
      _conversionStatus = 'Preparing document...';
    });

    try {
      final pdf = pw.Document();
      final int quality = _getQualityValue();
      final int maxDim = _getMaxDimension();

      for (int i = 0; i < _selectedImages.length; i++) {
        if (!mounted) return;
        setState(() {
          _conversionStatus = 'Processing page ${i + 1} of ${_selectedImages.length}...';
        });

        final imgFile = _selectedImages[i];
        Uint8List? imageBytes;

        if (_qualityMode == 'Original') {
          // Pure 100% original untouched raw bytes for maximum sharpness
          imageBytes = await imgFile.readAsBytes();
        } else {
          imageBytes = await FlutterImageCompress.compressWithFile(
            imgFile.absolute.path,
            minWidth: maxDim,
            minHeight: maxDim,
            quality: quality,
            format: CompressFormat.jpeg,
          );
          imageBytes ??= await imgFile.readAsBytes();
        }

        final pwImage = pw.MemoryImage(imageBytes);

        final pageFormat = _pageOrientation == 'Portrait'
            ? PdfPageFormat.a4
            : PdfPageFormat.a4.landscape;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(12),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pwImage,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      setState(() {
        _conversionStatus = 'Saving PDF document...';
      });

      // Save PDF into application temp then export to Android public MediaStore Downloads
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      final pdfBytes = await pdf.save();
      await tempFile.writeAsBytes(pdfBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: fileName,
      );

      setState(() => _isConverting = false);

      if (!mounted) return;
      InterstitialAdManager().showAd(
        onDismissed: () {
          if (!mounted) return;
          _showSuccessDialog(publicSavedPath, fileName);
        },
      );
    } catch (e) {
      setState(() => _isConverting = false);
      _showSnackbar('PDF conversion failed: $e');
    }
  }

  void _showSuccessDialog(String path, String name) {
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
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              'PDF Created Successfully!',
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
                color: Color(0xFFE5252A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_selectedImages.length} ${_selectedImages.length == 1 ? "page" : "pages"} • $sizeStr • $_qualityMode Quality',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 14),

            // Native Ad inside Image to PDF Success Dialog
            const NativeAdWidget(templateType: NativeTemplateStyleType.small),

            const SizedBox(height: 14),

            // Open in Viewer Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5252A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.visibility_rounded, size: 20),
                label: const Text('Open in Viewer', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text('Share PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(path)],
                      text: 'Created with PDF Reader & Tools',
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

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PDF Layout & Quality Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 20),

                // Image Quality Options
                const Text(
                  'IMAGE QUALITY & FILE SIZE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Original (HD)',
                        icon: Icons.hd_rounded,
                        isSelected: _qualityMode == 'Original',
                        onTap: () {
                          setState(() => _qualityMode = 'Original');
                          setModalState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'High (Sharp)',
                        icon: Icons.high_quality_rounded,
                        isSelected: _qualityMode == 'High',
                        onTap: () {
                          setState(() => _qualityMode = 'High');
                          setModalState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Medium (Balanced)',
                        icon: Icons.compress_rounded,
                        isSelected: _qualityMode == 'Medium',
                        onTap: () {
                          setState(() => _qualityMode = 'Medium');
                          setModalState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Low (Small Size)',
                        icon: Icons.speed_rounded,
                        isSelected: _qualityMode == 'Low',
                        onTap: () {
                          setState(() => _qualityMode = 'Low');
                          setModalState(() {});
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Orientation
                const Text(
                  'PAGE ORIENTATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Portrait',
                        icon: Icons.portrait_rounded,
                        isSelected: _pageOrientation == 'Portrait',
                        onTap: () {
                          setState(() => _pageOrientation = 'Portrait');
                          setModalState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Landscape',
                        icon: Icons.landscape_rounded,
                        isSelected: _pageOrientation == 'Landscape',
                        onTap: () {
                          setState(() => _pageOrientation = 'Landscape');
                          setModalState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5252A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5252A).withValues(alpha: 0.1) : const Color(0xFFF8F9FA),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5252A) : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFE5252A) : const Color(0xFF6E6E6E),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFE5252A) : const Color(0xFF424242),
                  fontSize: 12.5,
                ),
              ),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Image to PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E1E1E)),
            tooltip: 'Settings',
            onPressed: _showOptionsBottomSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isConverting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE5252A)),
                  const SizedBox(height: 20),
                  Text(
                    _conversionStatus.isNotEmpty ? _conversionStatus : 'Generating PDF...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quality: $_qualityMode • 100% On-Device',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                        icon: Icon(Icons.edit_note_rounded, color: Color(0xFFE5252A)),
                        hintText: 'Enter PDF file name...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                // Selected Images Area
                Expanded(
                  child: _selectedImages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5252A).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 48,
                                  color: Color(0xFFE5252A),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No Images Selected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pick photos from gallery or capture with camera',
                                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE5252A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                                    onPressed: _pickFromGallery,
                                  ),
                                  const SizedBox(width: 14),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E1E1E),
                                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                                    onPressed: _pickFromCamera,
                                  ),
                                ],
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_selectedImages.length} ${_selectedImages.length == 1 ? "Image" : "Images"} • Hold & drag to reorder',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFE5252A)),
                                        tooltip: 'Add more photos',
                                        onPressed: _pickFromGallery,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFE5252A)),
                                        tooltip: 'Take photo',
                                        onPressed: _pickFromCamera,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _selectedImages.length,
                                onReorder: _reorderImages,
                                itemBuilder: (context, index) {
                                  final img = _selectedImages[index];
                                  return Container(
                                    key: ValueKey(img.path),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          img,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      title: Text(
                                        'Page ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      subtitle: Text(
                                        img.path.split('/').last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
                                            onPressed: () => _removeImage(index),
                                          ),
                                          const Icon(Icons.drag_handle_rounded, color: Color(0xFFB0B0B0)),
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
                if (_selectedImages.isNotEmpty)
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
                            backgroundColor: const Color(0xFFE5252A),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFFE5252A).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                          label: Text(
                            'Convert to PDF (${_selectedImages.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _convertToPdf,
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
