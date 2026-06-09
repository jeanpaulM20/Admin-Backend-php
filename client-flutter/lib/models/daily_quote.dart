class DailyQuote {
  final String text;
  final String author;

  const DailyQuote({required this.text, required this.author});

  factory DailyQuote.fromJson(Map<String, dynamic> json) => DailyQuote(
        text: json['text']?.toString() ?? '',
        author: json['author']?.toString() ?? '',
      );
}
