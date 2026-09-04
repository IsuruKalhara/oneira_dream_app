import 'package:flutter_test/flutter_test.dart';
import 'package:dreamlore_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsService> _service() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsService(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh install: not onboarded, no intent, mic not prompted', () async {
    final s = await _service();
    expect(s.onboarded, isFalse);
    expect(s.intent, isNull);
    expect(s.micPrompted, isFalse);
  });

  test('intent round-trips through storage by id', () async {
    final s = await _service();
    await s.setIntent(DreamIntent.recurring);
    expect(s.intent, DreamIntent.recurring);
    await s.setIntent(null); // skipped → cleared
    expect(s.intent, isNull);
  });

  test('unknown stored intent id from a newer build falls back to null', () {
    // Never crash the Record screen over a forward-compat id.
    expect(DreamIntent.fromId('shadow_work'), isNull);
    expect(DreamIntent.fromId(null), isNull);
    expect(DreamIntent.fromId('recall'), DreamIntent.recall);
  });

  test('onboarded + micPrompted persist', () async {
    final s = await _service();
    await s.setOnboarded(true);
    await s.setMicPrompted(true);
    expect(s.onboarded, isTrue);
    expect(s.micPrompted, isTrue);
  });
}
