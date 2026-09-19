import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchline/core/services/sound_service.dart';
import 'package:touchline/core/storage/prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sound & Haptics Settings and Service Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PrefsService defaults sound and haptics to true', () async {
      final prefs = PrefsService.instance;
      final sound = await prefs.isSoundEnabled();
      final haptics = await prefs.isHapticsEnabled();

      expect(sound, isTrue);
      expect(haptics, isTrue);
    });

    test('PrefsService persists sound toggle changes', () async {
      final prefs = PrefsService.instance;

      await prefs.setSoundEnabled(false);
      expect(await prefs.isSoundEnabled(), isFalse);

      await prefs.setSoundEnabled(true);
      expect(await prefs.isSoundEnabled(), isTrue);
    });

    test('PrefsService persists haptics toggle changes', () async {
      final prefs = PrefsService.instance;

      await prefs.setHapticsEnabled(false);
      expect(await prefs.isHapticsEnabled(), isFalse);

      await prefs.setHapticsEnabled(true);
      expect(await prefs.isHapticsEnabled(), isTrue);
    });

    test('SoundService initializes state from PrefsService', () async {
      final prefs = PrefsService.instance;
      await prefs.setSoundEnabled(false);
      await prefs.setHapticsEnabled(false);

      final soundService = SoundService.instance;
      await soundService.init();

      expect(soundService.soundEnabled, isFalse);
      expect(soundService.hapticsEnabled, isFalse);

      // Re-enable
      soundService.soundEnabled = true;
      expect(soundService.soundEnabled, isTrue);
      expect(await prefs.isSoundEnabled(), isTrue);

      soundService.hapticsEnabled = true;
      expect(soundService.hapticsEnabled, isTrue);
      expect(await prefs.isHapticsEnabled(), isTrue);
    });

    test('SoundService sound triggers execute safely without crashing', () async {
      final soundService = SoundService.instance;
      await soundService.init();

      // Test with sound enabled
      soundService.soundEnabled = true;
      await expectLater(soundService.playWhistle(), completes);
      await expectLater(soundService.playGoal(), completes);
      await expectLater(soundService.playCorrect(), completes);
      await expectLater(soundService.playWrong(), completes);
      await expectLater(soundService.playClick(), completes);
      await expectLater(soundService.playKick(), completes);

      // Test with sound disabled
      soundService.soundEnabled = false;
      await expectLater(soundService.playWhistle(), completes);
      await expectLater(soundService.playGoal(), completes);
      await expectLater(soundService.playCorrect(), completes);
      await expectLater(soundService.playWrong(), completes);
      await expectLater(soundService.playClick(), completes);
      await expectLater(soundService.playKick(), completes);
    });

    test('SoundService haptic triggers execute safely without crashing', () async {
      final soundService = SoundService.instance;
      await soundService.init();

      // Test with haptics enabled
      soundService.hapticsEnabled = true;
      expect(() => soundService.lightHaptic(), returnsNormally);
      expect(() => soundService.mediumHaptic(), returnsNormally);
      expect(() => soundService.heavyHaptic(), returnsNormally);
      expect(() => soundService.selectionHaptic(), returnsNormally);
      expect(() => soundService.vibrateHaptic(), returnsNormally);

      // Test with haptics disabled
      soundService.hapticsEnabled = false;
      expect(() => soundService.lightHaptic(), returnsNormally);
      expect(() => soundService.mediumHaptic(), returnsNormally);
      expect(() => soundService.heavyHaptic(), returnsNormally);
      expect(() => soundService.selectionHaptic(), returnsNormally);
      expect(() => soundService.vibrateHaptic(), returnsNormally);
    });
  });
}
