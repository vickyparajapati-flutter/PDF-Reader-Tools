import 'package:flutter/material.dart';
import '../models/pdf_document_model.dart';
import 'pdf_viewer_screen.dart';
import 'widgets/native_ad_widget.dart';

class FavoritesTab extends StatefulWidget {
  final List<PdfDocumentModel> allFiles;
  final Function(PdfDocumentModel) onToggleFavorite;

  const FavoritesTab({
    super.key,
    required this.allFiles,
    required this.onToggleFavorite,
  });

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  @override
  Widget build(BuildContext context) {
    final favorites = widget.allFiles.where((f) => f.isFavorite).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Starred & Favorites',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 48,
                      color: Color(0xFFFFA000),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No Starred Files Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Star your important PDFs to access them quickly here.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: favorites.length,
              separatorBuilder: (context, index) {
                // Show native ad after every 5 starred files
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
                final file = favorites[index];
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFA000),
                      ),
                      onPressed: () {
                        widget.onToggleFavorite(file);
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
