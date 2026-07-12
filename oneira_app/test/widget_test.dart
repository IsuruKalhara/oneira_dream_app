import 'package:flutter_test/flutter_test.dart';
import 'package:oneira_app/data/safety.dart';

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
  });
}
