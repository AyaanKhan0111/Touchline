import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../storage/prefs_service.dart';

enum SoundEffect {
  whistle,
  goal,
  correct,
  wrong,
  click,
  kick,
}

/// Centralized audio and haptic feedback service for Touchline (Fix 18).
/// Controls tactile and sound effects for goals, whistles, correct/wrong guesses,
/// kicks, and clicks, adhering to user toggles in Settings.
class SoundService {
  static final SoundService instance = SoundService._();
  SoundService._();

  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _isInitialized = false;

  AudioPlayer? _player;

  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) => setSoundEnabled(value);

  bool get hapticsEnabled => _hapticsEnabled;
  set hapticsEnabled(bool value) => setHapticsEnabled(value);

  Future<void> init() async {
    if (_isInitialized) return;
    _soundEnabled = await PrefsService.instance.isSoundEnabled();
    _hapticsEnabled = await PrefsService.instance.isHapticsEnabled();

    try {
      _player = AudioPlayer();
      await _player?.setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // Graceful fallback if native audio drivers are unavailable
    }
    _isInitialized = true;
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    PrefsService.instance.setSoundEnabled(enabled);
  }

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    PrefsService.instance.setHapticsEnabled(enabled);
  }

  Future<void> playSound(SoundEffect effect) async {
    if (!_soundEnabled) return;

    try {
      String assetPath;
      switch (effect) {
        case SoundEffect.whistle:
          assetPath = 'audio/whistle.wav';
          break;
        case SoundEffect.goal:
          assetPath = 'audio/goal.wav';
          break;
        case SoundEffect.correct:
          assetPath = 'audio/correct.wav';
          break;
        case SoundEffect.wrong:
          assetPath = 'audio/wrong.wav';
          break;
        case SoundEffect.click:
          assetPath = 'audio/click.wav';
          break;
        case SoundEffect.kick:
          assetPath = 'audio/kick.wav';
          break;
      }

      _player ??= AudioPlayer();
      await _player?.stop();
      await _player?.play(AssetSource(assetPath));
    } catch (_) {
      // Fallback to system audio cues if asset player is unavailable
      if (effect == SoundEffect.wrong) {
        SystemSound.play(SystemSoundType.alert);
      } else {
        SystemSound.play(SystemSoundType.click);
      }
    }
  }

  // Convenience Sound + Haptic Triggers
  Future<void> playWhistle() async {
    mediumHaptic();
    await playSound(SoundEffect.whistle);
  }

  Future<void> playGoal() async {
    heavyHaptic();
    await playSound(SoundEffect.goal);
  }

  Future<void> playCorrect() async {
    mediumHaptic();
    await playSound(SoundEffect.correct);
  }

  Future<void> playWrong() async {
    vibrateHaptic();
    await playSound(SoundEffect.wrong);
  }

  Future<void> playClick() async {
    lightHaptic();
    await playSound(SoundEffect.click);
  }

  Future<void> playKick() async {
    lightHaptic();
    await playSound(SoundEffect.kick);
  }

  // Haptic feedback methods (guarded by user toggle)
  void lightHaptic() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  void mediumHaptic() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  void heavyHaptic() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  void vibrateHaptic() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  void selectionHaptic() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }
}
