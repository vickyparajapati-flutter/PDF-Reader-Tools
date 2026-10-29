import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_document_model.dart';

class StorageHelper {
  static const MethodChannel _channel = MethodChannel('com.allpdftools/media_store');

  /// Saves a generated PDF into the Android Public Download/PDFReader folder
  /// via Android MediaStore (100% compliant with Android 11, 12, 13, 14, 15).
  static Future<String> savePdfToPublicDownloads({
    required File tempFile,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      try {
        final String? publicPath = await _channel.invokeMethod<String>(
          'saveToPublicDownload',
          {
            'srcPath': tempFile.path,
            'fileName': fileName,
          },
        );
        if (publicPath != null) {
          return publicPath;
        }
      } catch (e) {
        // Fallback to internal storage if method channel fails
      }
    }
    return tempFile.path;
  }

  /// Saves an exported Image into the Android Public Pictures/PDFReader folder
  /// via Android MediaStore (instant gallery visibility).
  static Future<String> saveImageToPublicPictures({
    required File tempFile,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      try {
        final String? publicPath = await _channel.invokeMethod<String>(
          'saveImageToGallery',
          {
            'srcPath': tempFile.path,
            'fileName': fileName,
          },
        );
        if (publicPath != null) {
          return publicPath;
        }
      } catch (e) {
        // Fallback to internal storage
      }
    }
    return tempFile.path;
  }

  /// Scans both Android MediaStore (public Downloads) and local App documents
  static Future<List<PdfDocumentModel>> getAllPdfDocuments() async {
    final List<PdfDocumentModel> list = [];

    // 1. Fetch from Android MediaStore (Downloads / PDFReader)
    if (Platform.isAndroid) {
      try {
        final List<dynamic>? mediaStoreFiles =
            await _channel.invokeMethod<List<dynamic>>('getCreatedPdfs');

        if (mediaStoreFiles != null) {
          for (var item in mediaStoreFiles) {
            final map = Map<String, dynamic>.from(item);
            final String name = map['name'] ?? 'Document.pdf';
            final String path = map['path'] ?? '';
            final int size = (map['size'] as num?)?.toInt() ?? 0;
            final int dateMs = (map['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

            list.add(
              PdfDocumentModel(
                path: path,
                name: name,
                sizeInBytes: size,
                modifiedDate: DateTime.fromMillisecondsSinceEpoch(dateMs),
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 2. Also scan App Documents Directory
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      if (await appDocDir.exists()) {
        final files = appDocDir.listSync(recursive: true);
        for (var f in files) {
          if (f is File && f.path.toLowerCase().endsWith('.pdf')) {
            final name = f.path.split('/').last;
            // Prevent duplicate display if already in list
            if (!list.any((p) => p.name == name)) {
              final stat = await f.stat();
              list.add(
                PdfDocumentModel(
                  path: f.path,
                  name: name,
                  sizeInBytes: stat.size,
                  modifiedDate: stat.modified,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // Sort by latest modified date
    list.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));

    return list;
  }
}
