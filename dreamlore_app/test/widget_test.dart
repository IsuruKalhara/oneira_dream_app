import 'package:flutter_test/flutter_test.dart';
import 'package:dreamlore_app/data/safety.dart';

void main() {
  group('SafetyCheck', () {
    test('flags expressed self-harm intent', () {
      expect(SafetyCheck.isConcerning('I want to die'), isTrue);
      expect(SafetyCheck.isConcerning('I keep thinking about killing myself'), isTrue);
      expect(SafetyCheck.isConcerning('there is no reason to live'), isTrue);
    });

    test('does NOT flag ordinary dream imagery about death', () {
      expect(SafetyCheck.isConcerning('I dreamed I died and floated above the city'), isFalse);
      expect(SafetyCheck.isConcerning('a snake chased me through a dark forest'), isFalse);
      expect(SafetyCheck.isConcerning('my teeth fell out one by one'), isFalse);
    });

    test('does NOT flag being attacked in a dream — the most common nightmare',
        () {
      // These used to match the old `(kill|hurt|harm) ... me` pattern and
      // answered an ordinary nightmare with a suicide-hotline card.
      expect(
          SafetyCheck.isConcerning('a man was chasing me and trying to kill me'),
          isFalse);
      expect(SafetyCheck.isConcerning('the shadow was killing me'), isFalse);
      expect(SafetyCheck.isConcerning('it kept hurting me in the dream'),
          isFalse);
    });

    test('flags the broader ideation phrasings the old list missed', () {
      expect(SafetyCheck.isConcerning('I want to end my life'), isTrue);
      expect(SafetyCheck.isConcerning('honestly I wanna die'), isTrue);
      expect(SafetyCheck.isConcerning('there is no point in living'), isTrue);
      expect(
          SafetyCheck.isConcerning('everyone is better off without me'), isTrue);
    });
  });
}
