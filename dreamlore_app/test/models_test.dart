import 'package:flutter_test/flutter_test.dart';
import 'package:dreamlore_app/data/models.dart';

void main() {
  group('QuotaInfo', () {
    test('parses a /usage payload', () {
      final q = QuotaInfo.fromUsageJson({
        'tier': 'paid',
        'day': {'used': 2, 'limit': 3},
        'month': {'used': 10, 'limit': 50},
      });
      expect(q.tier, 'paid');
      expect(q.isPaid, isTrue);
      expect(q.dayRemaining, 1);
    });

    test('missing fields default instead of throwing', () {
      final q = QuotaInfo.fromUsageJson(const {});
      expect(q.tier, 'free');
      expect(q.dayRemaining, 0);
    });

    test('dayRemaining clamps when used exceeds limit', () {
      const q = QuotaInfo(
          tier: 'free', dayUsed: 5, dayLimit: 1, monthUsed: 5, monthLimit: 5);
      expect(q.dayRemaining, 0); // never negative in the quota pill
    });
  });

  group('Interpretation', () {
    test('parses a full /explain payload', () {
      final i = Interpretation.fromJson({
        'explanation': 'A reading.',
        'reflection': 'A question?',
        'symbols': [
          {'symbol': 'Water', 'meaning': 'depth'},
        ],
        'quotes': [
          {'book': 'Dream Psychology', 'author': 'Freud', 'text': 'Verbatim.'},
        ],
        '_meta': {'model': 'claude-opus-5'},
      });
      expect(i.symbols.single.symbol, 'Water');
      expect(i.quotes.single.author, 'Freud');
      expect(i.model, 'claude-opus-5');
    });

    test('empty payload yields empty, renderable interpretation', () {
      final i = Interpretation.fromJson(const {});
      expect(i.explanation, '');
      expect(i.symbols, isEmpty);
      expect(i.quotes, isEmpty);
    });

    test('symbols/quotes JSON round-trips through the DB columns', () {
      final i = Interpretation.fromJson({
        'explanation': 'x',
        'reflection': '',
        'symbols': [
          {'symbol': 'Snake', 'meaning': 'folk meaning'},
        ],
        'quotes': [
          {'book': 'B', 'author': 'A', 'text': 'T'},
        ],
      });
      // The repository stores these strings; the journal parses them back.
      expect(i.symbolsJson(), contains('Snake'));
      expect(i.quotesJson(), contains('"author":"A"'));
    });
  });
}
