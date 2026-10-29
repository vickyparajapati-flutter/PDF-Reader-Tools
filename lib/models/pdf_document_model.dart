import 'dart:io';

class PdfDocumentModel {
  final String path;
  final String name;
  final int sizeInBytes;
  final DateTime modifiedDate;
  final bool isFavorite;

  PdfDocumentModel({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.modifiedDate,
    this.isFavorite = false,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${modifiedDate.day.toString().padLeft(2, '0')}/${modifiedDate.month.toString().padLeft(2, '0')}/${modifiedDate.year}';
  }

  File get file => File(path);
}
