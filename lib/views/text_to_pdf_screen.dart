import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/storage_helper.dart';
import '../models/ad_helper.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/banner_ad_widget.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});

  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _isGenerating = false;

  // Formatting Options
  double _fontSize = 12.0; // 10, 12, 14, 16
  int _fontFamilyIndex = 0; // 0: Helvetica, 1: TimesRoman, 2: Courier
  int _pageSizeIndex = 0; // 0: A4, 1: Letter

  @override
  void initState() {
    super.initState();
    InterstitialAdManager().loadAd();
    final uniqueStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _fileNameController.text = 'Document_$uniqueStamp';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickTextFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final text = await file.readAsString();
        final baseName = file.path.split('/').last.replaceAll('.txt', '');

        setState(() {
          _titleController.text = baseName;
          _contentController.text = text;
          _fileNameController.text = '${baseName}_pdf';
        });
      }
    } catch (e) {
      _showSnackbar('Error reading text file: $e');
    }
  }

  Future<void> _generatePdf() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnackbar('Please enter or import some text content');
      return;
    }

    final outName = _fileNameController.text.trim();
    if (outName.isEmpty) {
      _showSnackbar('Please enter output file name');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final doc = PdfDocument();
      doc.pageSettings.size = _pageSizeIndex == 0 ? PdfPageSize.a4 : PdfPageSize.letter;
      doc.pageSettings.margins.all = 40;

      // Font Families
      PdfFontFamily family = PdfFontFamily.helvetica;
      if (_fontFamilyIndex == 1) family = PdfFontFamily.timesRoman;
      if (_fontFamilyIndex == 2) family = PdfFontFamily.courier;

      final bodyFont = PdfStandardFont(family, _fontSize);
      final title = _titleController.text.trim();

      // Create a text element with auto page breaking / pagination
      final fullText = title.isNotEmpty ? '$title\n\n$content' : content;

      final textElement = PdfTextElement(
        text: fullText,
        font: bodyFont,
        brush: PdfSolidBrush(PdfColor(30, 30, 30)),
      );

      final format = PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
        breakType: PdfLayoutBreakType.fitPage,
      );

      final page = doc.pages.add();
      final bounds = Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height);

      textElement.draw(
        page: page,
        bounds: bounds,
        format: format,
      );

      final savedBytes = doc.saveSync();
      final totalPages = doc.pages.count;
      doc.dispose();

      // Save to public Downloads/PDFReader
      final tempDir = await getTemporaryDirectory();
      final finalFileName = outName.toLowerCase().endsWith('.pdf') ? outName : '$outName.pdf';
      final tempFile = File('${tempDir.path}/$finalFileName');
      await tempFile.writeAsBytes(savedBytes);

      final publicSavedPath = await StorageHelper.savePdfToPublicDownloads(
        tempFile: tempFile,
        fileName: finalFileName,
      );

      setState(() => _isGenerating = false);

      if (mounted) {
        InterstitialAdManager().showAd(
          onDismissed: () {
            if (!mounted) return;
            _showSuccessDialog(publicSavedPath, finalFileName, totalPages);
          },
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackbar('Failed to create PDF: $e');
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

  void _showSuccessDialog(String savedPath, String fileName, int pages) {
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
                  color: const Color(0xFFFFA000).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFFFA000),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'PDF Created!',
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
                  color: Color(0xFFFFA000),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$pages pages generated • Saved to Download/PDFReader',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Sharing created PDF: $fileName',
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
                        backgroundColor: const Color(0xFFFFA000),
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
          'Text to PDF',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickTextFile,
            icon: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFFFFA000)),
            label: const Text(
              'Import .txt',
              style: TextStyle(color: Color(0xFFFFA000), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFA000)),
                  SizedBox(height: 20),
                  Text(
                    'Generating paginated PDF...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title Field
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Document Title (Optional)',
                    hintText: 'e.g. Project Notes, Meeting Summary',
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFA000), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                const SizedBox(height: 14),

                // Main Content Field
                TextField(
                  controller: _contentController,
                  maxLines: 12,
                  decoration: InputDecoration(
                    labelText: 'Document Text / Content',
                    hintText: 'Type, paste text or import a .txt file here...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFA000), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 20),

                // Styling Options Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DOCUMENT STYLING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Font Family
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Font Style:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('Modern', style: TextStyle(fontSize: 12))),
                                ButtonSegment(value: 1, label: Text('Classic', style: TextStyle(fontSize: 12))),
                                ButtonSegment(value: 2, label: Text('Mono', style: TextStyle(fontSize: 12))),
                              ],
                              selected: {_fontFamilyIndex},
                              onSelectionChanged: (val) {
                                setState(() => _fontFamilyIndex = val.first);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Font Size Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Text Size:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '${_fontSize.toInt()} pt',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      Slider(
                        value: _fontSize,
                        min: 10,
                        max: 18,
                        divisions: 4,
                        activeColor: const Color(0xFFFFA000),
                        onChanged: (val) => setState(() => _fontSize = val),
                      ),

                      const Divider(),
                      const SizedBox(height: 8),

                      // Page Size
                      Row(
                        children: [
                          const Text('Page Size:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          ChoiceChip(
                            label: const Text('A4'),
                            selected: _pageSizeIndex == 0,
                            selectedColor: const Color(0xFFFFECB3),
                            onSelected: (_) => setState(() => _pageSizeIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Letter'),
                            selected: _pageSizeIndex == 1,
                            selectedColor: const Color(0xFFFFECB3),
                            onSelected: (_) => setState(() => _pageSizeIndex = 1),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFA000), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),

                const SizedBox(height: 28),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                    label: const Text(
                      'Convert to PDF',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    onPressed: _generatePdf,
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
