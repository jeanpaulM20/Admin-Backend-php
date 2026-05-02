class ClientFile {
  final String id;
  final String name;
  final String? url;
  final DateTime? date;

  ClientFile({
    required this.id,
    required this.name,
    this.url,
    this.date,
  });

  factory ClientFile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return ClientFile(
      id: json['id']?.toString() ?? '',
      name: json['filename']?.toString() ?? json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? json['file']?.toString() ?? json['path']?.toString(),
      date: parseDate(json['created_at'] ?? json['createdAt'] ?? json['date']),
    );
  }
}
