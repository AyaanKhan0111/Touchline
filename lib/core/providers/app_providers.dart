import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_service.dart';
import '../database/save_service.dart';
import '../storage/prefs_service.dart';
import '../../domain/models/player.dart';

final dbServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final saveServiceProvider = Provider<SaveService>((ref) {
  return SaveService.instance;
});

final prefsServiceProvider = Provider<PrefsService>((ref) {
  return PrefsService.instance;
});

class ManagerNameNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'Gaffer';
  }

  Future<void> _load() async {
    final name = await ref.read(prefsServiceProvider).getManagerName();
    if (name != null && name.isNotEmpty) {
      state = name;
    }
  }

  Future<void> setName(String name) async {
    await ref.read(prefsServiceProvider).setManagerName(name);
    state = name;
  }
}

final managerNameProvider = NotifierProvider<ManagerNameNotifier, String>(ManagerNameNotifier.new);

class CoinsNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 50;
  }

  Future<void> _load() async {
    state = await ref.read(prefsServiceProvider).getCoins();
  }

  Future<void> add(int delta, String reason) async {
    await ref.read(prefsServiceProvider).addCoins(delta);
    await ref.read(saveServiceProvider).recordCoinTransaction(delta, reason);
    state = await ref.read(prefsServiceProvider).getCoins();
  }
}

final coinsProvider = NotifierProvider<CoinsNotifier, int>(CoinsNotifier.new);

class ThemeModeNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'dark';
  }

  Future<void> _load() async {
    state = await ref.read(prefsServiceProvider).getThemeMode();
  }

  Future<void> setMode(String mode) async {
    await ref.read(prefsServiceProvider).setThemeMode(mode);
    state = mode;
  }

  Future<void> toggle() async {
    final next = state == 'dark' ? 'light' : 'dark';
    await setMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, String>(ThemeModeNotifier.new);

class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    state = await ref.read(prefsServiceProvider).isSoundEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(prefsServiceProvider).setSoundEnabled(enabled);
    state = enabled;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(SoundEnabledNotifier.new);

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    state = await ref.read(prefsServiceProvider).isHapticsEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(prefsServiceProvider).setHapticsEnabled(enabled);
    state = enabled;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final hapticsEnabledProvider = NotifierProvider<HapticsEnabledNotifier, bool>(HapticsEnabledNotifier.new);

class PlayerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
  void setQuery(String q) => state = q;
}

final playerSearchQueryProvider = NotifierProvider<PlayerSearchQueryNotifier, String>(PlayerSearchQueryNotifier.new);

final playerSearchResultsProvider = FutureProvider.autoDispose<List<Player>>((ref) async {
  final query = ref.watch(playerSearchQueryProvider);
  if (query.trim().isEmpty) return [];
  final dbService = ref.watch(dbServiceProvider);
  return await dbService.searchPlayers(query, limit: 30);
});

final dbMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dbService = ref.watch(dbServiceProvider);
  return await dbService.getDatabaseMetrics();
});
