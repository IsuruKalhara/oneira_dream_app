import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneira_app/features/onboarding/onboarding_controller.dart';
import 'package:oneira_app/providers/providers.dart';
import 'package:oneira_app/services/settings_service.dart';
import 'package:oneira_app/services/stt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake STT so tests never touch the platform channel.
class _FakeStt extends SttService {
  _FakeStt({this.grant = true, this.explode = false});
  final bool grant;
  final bool explode;

  @override
  Future<bool> init() async {
    if (explode) throw StateError('platform channel down');
    return grant;
  }
}

Future<ProviderContainer> _container({SttService? stt}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (stt != null) sttServiceProvider.overrideWithValue(stt),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('page navigation is clamped to the five steps', () async {
    final c = await _container();
    final ctl = c.read(onboardingControllerProvider.notifier);
    ctl.back(); // below zero → no-op
    expect(c.read(onboardingControllerProvider).page, 0);
    for (var i = 0; i < 10; i++) {
      ctl.next(); // past the end → clamped
    }
    expect(c.read(onboardingControllerProvider).page,
        OnboardingController.stepCount - 1);
  });

  test('tapping the selected intent again clears it (optional question)',
      () async {
    final c = await _container();
    final ctl = c.read(onboardingControllerProvider.notifier);
    ctl.selectIntent(DreamIntent.patterns);
    expect(c.read(onboardingControllerProvider).intent, DreamIntent.patterns);
    ctl.selectIntent(DreamIntent.patterns);
    expect(c.read(onboardingControllerProvider).intent, isNull);
  });

  test('skipIntent clears the selection and advances', () async {
    final c = await _container();
    final ctl = c.read(onboardingControllerProvider.notifier);
    ctl.goTo(1);
    ctl.selectIntent(DreamIntent.recall);
    ctl.skipIntent();
    final s = c.read(onboardingControllerProvider);
    expect(s.intent, isNull);
    expect(s.page, 2);
  });

  test('granted mic → granted status, micPrompted persisted', () async {
    final c = await _container(stt: _FakeStt(grant: true));
    final ctl = c.read(onboardingControllerProvider.notifier);
    expect(await ctl.requestMic(), MicStatus.granted);
    expect(c.read(settingsServiceProvider).micPrompted, isTrue);
  });

  test('denied mic → denied status, never throws, busy resets', () async {
    final c = await _container(stt: _FakeStt(grant: false));
    final ctl = c.read(onboardingControllerProvider.notifier);
    expect(await ctl.requestMic(), MicStatus.denied);
    expect(c.read(onboardingControllerProvider).busy, isFalse);
  });

  test('a platform-channel explosion is treated as denial, not a crash',
      () async {
    final c = await _container(stt: _FakeStt(explode: true));
    final ctl = c.read(onboardingControllerProvider.notifier);
    expect(await ctl.requestMic(), MicStatus.denied);
    expect(c.read(onboardingControllerProvider).busy, isFalse);
  });

  test('complete() persists intent and onboarded together', () async {
    final c = await _container();
    final ctl = c.read(onboardingControllerProvider.notifier);
    ctl.selectIntent(DreamIntent.recurring);
    await ctl.complete();
    final settings = c.read(settingsServiceProvider);
    expect(settings.onboarded, isTrue);
    expect(settings.intent, DreamIntent.recurring);
  });

  test('complete() after "I\'ll type instead" persists skipped mic + no intent',
      () async {
    final c = await _container();
    final ctl = c.read(onboardingControllerProvider.notifier);
    ctl.skipMic();
    await ctl.complete();
    expect(c.read(onboardingControllerProvider).mic, MicStatus.skipped);
    expect(c.read(settingsServiceProvider).onboarded, isTrue);
    expect(c.read(settingsServiceProvider).intent, isNull);
  });
}
