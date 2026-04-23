import 'package:intl/intl.dart';

class FileItem {
  final int? id;
  final String? name;
  final String? file;
  final String? date;
  final DateTime? uploadedAt;

  const FileItem({
    this.id,
    this.name,
    this.file,
    this.date,
    this.uploadedAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    DateTime? uploaded;
    final rawDate = json['date']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        uploaded = DateTime.tryParse(rawDate) ??
            DateFormat('dd.MM.yyyy HH:mm:ss').tryParse(rawDate) ??
            DateFormat('dd.MM.yyyy HH:mm').tryParse(rawDate) ??
            DateFormat('dd.MM.yyyy').tryParse(rawDate);
      } catch (_) {}
    }

    return FileItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString(),
      file: json['file']?.toString(),
      date: rawDate,
      uploadedAt: uploaded,
    );
  }

  String get displayDate {
    if (uploadedAt != null) {
      return DateFormat('dd.MM.yyyy HH:mm').format(uploadedAt!);
    }
    return date ?? '';
  }

  String get displayName => name ?? file?.split('/').last ?? 'File';

  String? get extension {
    final n = displayName;
    final idx = n.lastIndexOf('.');
    if (idx == -1) return null;
    return n.substring(idx + 1).toUpperCase();
  }
}
