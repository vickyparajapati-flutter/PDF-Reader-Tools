import 'package:flutter/material.dart';
import 'image_to_pdf_screen.dart';
import 'pdf_to_images_screen.dart';
import 'text_to_pdf_screen.dart';
import 'extract_text_screen.dart';
import 'merge_pdf_screen.dart';
import 'split_pdf_screen.dart';
import 'reorder_pages_screen.dart';
import 'protect_pdf_screen.dart';
import 'unlock_pdf_screen.dart';
import 'compress_pdf_screen.dart';
import 'watermark_pdf_screen.dart';
import 'sign_pdf_screen.dart';
import 'widgets/native_ad_widget.dart';

class ToolsTab extends StatelessWidget {
  final VoidCallback? onFileCreated;

  const ToolsTab({super.key, this.onFileCreated});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PDF Toolbox',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header Banner with Tool Count
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5252A), Color(0xFFB5101A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '13 PRO TOOLS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '100% Free & Offline',
                            style: TextStyle(
                              color: Color(0xFFFFD5D7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All-in-One PDF Suite',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Fast, private, and secure tools. Scroll down to explore all 13 tools ↓',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.offline_bolt_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category 1: Convert to PDF
          const Text(
            'CONVERT & SCAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          _buildToolGrid([
            _ToolItem(
              icon: Icons.camera_alt_rounded,
              title: 'Image to PDF',
              subtitle: 'Scan camera & gallery',
              tag: 'POPULAR',
              color: const Color(0xFFE5252A),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImageToPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.image_rounded,
              title: 'PDF to Image',
              subtitle: 'Extract JPG / PNG',
              color: const Color(0xFF29B6F6),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PdfToImagesScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.text_snippet_rounded,
              title: 'Text to PDF',
              subtitle: 'Convert notes to file',
              color: const Color(0xFFFFA000),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TextToPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.document_scanner_rounded,
              title: 'Extract Text',
              subtitle: 'Extract text from PDF',
              color: const Color(0xFF7E57C2),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExtractTextScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
          ]),

          const SizedBox(height: 18),

          // Compact Sleek Native Ad Card inside Tools Tab
          const NativeAdWidget(templateType: NativeTemplateStyleType.small),

          const SizedBox(height: 18),

          // Category 2: Organize PDF
          const Text(
            'ORGANIZE & EDIT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          _buildToolGrid([
            _ToolItem(
              icon: Icons.call_merge_rounded,
              title: 'Merge PDF',
              subtitle: 'Combine multiple files',
              color: const Color(0xFF43A047),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MergePdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.call_split_rounded,
              title: 'Split PDF',
              subtitle: 'Extract pages',
              color: const Color(0xFF00ACC1),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SplitPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.reorder_rounded,
              title: 'Reorder Pages',
              subtitle: 'Rearrange page order',
              color: const Color(0xFF5C6BC0),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReorderPagesScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.draw_rounded,
              title: 'Sign PDF',
              subtitle: 'Add digital signature',
              color: const Color(0xFF673AB7),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.delete_sweep_rounded,
              title: 'Remove Pages',
              subtitle: 'Delete unwanted pages',
              color: const Color(0xFFE53935),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReorderPagesScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
          ]),

          const SizedBox(height: 18),

          // Second Native Ad after Category 2 (Organize & Edit)
          const NativeAdWidget(templateType: NativeTemplateStyleType.small),

          const SizedBox(height: 18),

          // Category 3: Security & Optimization
          const Text(
            'SECURITY & OPTIMIZE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          _buildToolGrid([
            _ToolItem(
              icon: Icons.lock_rounded,
              title: 'Protect PDF',
              subtitle: 'Add password encryption',
              color: const Color(0xFF3949AB),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProtectPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.lock_open_rounded,
              title: 'Unlock PDF',
              subtitle: 'Remove password',
              color: const Color(0xFF00897B),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnlockPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.compress_rounded,
              title: 'Compress PDF',
              subtitle: 'Reduce file size',
              color: const Color(0xFFD81B60),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompressPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
            _ToolItem(
              icon: Icons.branding_watermark_rounded,
              title: 'Watermark',
              subtitle: 'Add text or logo stamp',
              color: const Color(0xFFFB8C00),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WatermarkPdfScreen(),
                  ),
                );
                onFileCreated?.call();
              },
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToolGrid(List<_ToolItem> tools) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return InkWell(
          onTap: tool.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tool.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tool.icon, color: tool.color, size: 22),
                    ),
                    if (tool.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: tool.tag == 'PRO'
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFE5252A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tool.tag!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: tool.tag == 'PRO' ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? tag;
  final VoidCallback onTap;

  _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.tag,
    required this.onTap,
  });
}
