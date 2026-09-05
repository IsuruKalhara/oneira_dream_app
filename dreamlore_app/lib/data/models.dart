import 'dart:convert';

/// Structured interpretation returned by the proxy `/explain` endpoint.
class Interpretation {
  final String explanation;
  final String reflection;
  final List<DreamSymbol> symbols;
  final List<Quote> quotes;
  final String model;
  final String provider;

  const Interpretation({
    required this.explanation,
    required this.reflection,
    required this.symbols,
    required this.quotes,
    this.model = '',
    this.provider = '',
  });

  factory Interpretation.fromJson(Map<String, dynamic> j) => Interpretation(
    explanation: (j['explanation'] ?? '') as String,
    reflection: (j['reflection'] ?? '') as String,
    symbols: ((j['symbols'] ?? []) as List)
        .map((e) => DreamSymbol.fromJson(e as Map<String, dynamic>))
        .toList(),
    quotes: ((j['quotes'] ?? []) as List)
        .map((e) => Quote.fromJson(e as Map<String, dynamic>))
        .toList(),
    model: (j['_meta']?['model'] ?? j['provider'] ?? '') as String,
    provider: (j['provider'] ?? '') as String,
  );

  String symbolsJson() => jsonEncode(symbols.map((s) => s.toJson()).toList());
  String quotesJson() => jsonEncode(quotes.map((q) => q.toJson()).toList());
}

class DreamSymbol {
  final String symbol;
  final String meaning;
  const DreamSymbol({required this.symbol, required this.meaning});

  factory DreamSymbol.fromJson(Map<String, dynamic> j) => DreamSymbol(
    symbol: (j['symbol'] ?? '') as String,
    meaning: (j['meaning'] ?? '') as String,
  );
  Map<String, dynamic> toJson() => {'symbol': symbol, 'meaning': meaning};
}

class Quote {
  final String book;
  final String author;
  final String text;
  const Quote({required this.book, required this.author, required this.text});

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    book: (j['book'] ?? '') as String,
    author: (j['author'] ?? '') as String,
    text: (j['text'] ?? '') as String,
  );
  Map<String, dynamic> toJson() => {
    'book': book,
    'author': author,
    'text': text,
  };
}

/// Quota snapshot from `/usage` or attached to an `/explain` response.
class QuotaInfo {
  final String tier;
  final int dayUsed;
  final int dayLimit;
  final int monthUsed;
  final int monthLimit;

  const QuotaInfo({
    required this.tier,
    required this.dayUsed,
    required this.dayLimit,
    required this.monthUsed,
    required this.monthLimit,
  });

  int get dayRemaining => (dayLimit - dayUsed).clamp(0, dayLimit);
  bool get isPaid => tier == 'paid';

  factory QuotaInfo.fromUsageJson(Map<String, dynamic> j) => QuotaInfo(
    tier: (j['tier'] ?? 'free') as String,
    dayUsed: (j['day']?['used'] ?? 0) as int,
    dayLimit: (j['day']?['limit'] ?? 0) as int,
    monthUsed: (j['month']?['used'] ?? 0) as int,
    monthLimit: (j['month']?['limit'] ?? 0) as int,
  );
}

/// Thrown when the proxy returns 429 (daily/monthly cap hit).
class QuotaExceededException implements Exception {
  final String reason; // 'daily' | 'monthly'
  final DateTime? resetsAt;
  final bool upgrade; // true when a free user could upgrade
  const QuotaExceededException(
    this.reason, {
    this.resetsAt,
    this.upgrade = false,
  });

  @override
  String toString() => 'QuotaExceededException($reason)';
}
