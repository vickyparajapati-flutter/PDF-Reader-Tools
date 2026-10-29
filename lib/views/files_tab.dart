import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/pdf_document_model.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/native_ad_widget.dart';
import 'image_to_pdf_screen.dart';
import 'merge_pdf_screen.dart';
import 'compress_pdf_screen.dart';
import 'sign_pdf_screen.dart';

class FilesTab extends StatefulWidget {
  final List<PdfDocumentModel> files;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(PdfDocumentModel) onToggleFavorite;
  final VoidCallback onNavigateToTools;

  const FilesTab({
    super.key,
    required this.files,
    required this.isLoading,
    required this.onRefresh,
    required this.onToggleFavorite,
    required this.onNavigateToTools,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<PdfDocumentModel> get _filteredFiles {
    if (_searchQuery.trim().isEmpty) {
      return widget.files;
    }
    return widget.files
        .where((file) =>
            file.name.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  Future<void> _pickSinglePdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            filePath: files.first.path!,
            fileName: files.first.name,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'All PDF Files',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded, color: Color(0xFFE5252A)),
            tooltip: 'Browse Storage',
            onPressed: _pickSinglePdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF555555)),
            tooltip: 'Refresh Files',
            onPressed: widget.onRefresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
                decoration: InputDecoration(
                  hintText: 'Search PDF documents...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E8E93), size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Quick Tools Row on Home Screen
          if (_searchQuery.isEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'QUICK TOOLS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        InkWell(
                          onTap: widget.onNavigateToTools,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  'View All 13',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE5252A),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: Color(0xFFE5252A),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 78,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildQuickToolItem(
                          icon: Icons.camera_alt_rounded,
                          label: 'Scan / Image',
                          color: const Color(0xFFE5252A),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
                            );
                            widget.onRefresh();
                          },
                        ),
                        _buildQuickToolItem(
                          icon: Icons.call_merge_rounded,
                          label: 'Merge PDF',
                          color: const Color(0xFF43A047),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MergePdfScreen()),
                            );
                            widget.onRefresh();
                          },
                        ),
                        _buildQuickToolItem(
                          icon: Icons.compress_rounded,
                          label: 'Compress',
                          color: const Color(0xFFD81B60),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
                            );
                            widget.onRefresh();
                          },
                        ),
                        _buildQuickToolItem(
                          icon: Icons.draw_rounded,
                          label: 'Sign PDF',
                          color: const Color(0xFF673AB7),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignPdfScreen()),
                            );
                            widget.onRefresh();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),
                ],
              ),
            ),

          // File List Header & Count
          if (_searchQuery.isEmpty && !widget.isLoading && _filteredFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Text(
                    'ALL PDF DOCUMENTS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredFiles.length} files',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),

          // File List or Loading/Empty State
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE5252A),
                    ),
                  )
                : _filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFECEE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 48,
                                color: Color(0xFFE5252A),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching files found'
                                  : 'No PDF files found',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Tap "Browse File" to pick any PDF from your device storage.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _pickSinglePdf,
                              icon: const Icon(Icons.file_open_rounded, size: 18),
                              label: const Text('Browse Files'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5252A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          widget.onRefresh();
                        },
                        color: const Color(0xFFE5252A),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _filteredFiles.length,
                          separatorBuilder: (context, index) {
                            // Show native ad after every 5 files (index starts at 0, so after index 4, 9, 14...)
                            // Rendered only when reached, keeping request rate perfectly in sync with impressions
                            if ((index + 1) % 5 == 0) {
                              return const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: 8),
                                  NativeAdWidget(templateType: NativeTemplateStyleType.small),
                                  SizedBox(height: 8),
                                ],
                              );
                            }
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PdfViewerScreen(
                                        filePath: file.path,
                                        fileName: file.name,
                                      ),
                                    ),
                                  );
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5252A).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Color(0xFFE5252A),
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                subtitle: Text(
                                  '${file.formattedSize} • ${file.formattedDate}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        file.isFavorite
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: file.isFavorite
                                            ? const Color(0xFFFFA000)
                                            : const Color(0xFF8E8E93),
                                      ),
                                      onPressed: () {
                                        widget.onToggleFavorite(file);
                                      },
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Color(0xFFC7C7CC),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
