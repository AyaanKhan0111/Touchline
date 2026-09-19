import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing persistent preferences and game state indicators.
class PrefsService {
  static final PrefsService instance = PrefsService._();
  PrefsService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static const _keyManagerName = 'manager_name';
  static const _keyOnboardingDone = 'onboarding_done';
  static const _keyCoins = 'coins_balance';
  static const _keyDailyStreak = 'daily_streak';
  static const _keyLastDailyDate = 'last_daily_date';
  static const _keyThemeMode = 'theme_mode'; // 'system', 'dark', 'light'

  Future<String?> getManagerName() async {
    final p = await prefs;
    return p.getString(_keyManagerName);
  }

  Future<void> setManagerName(String name) async {
    final p = await prefs;
    await p.setString(_keyManagerName, name.trim());
    await p.setBool(_keyOnboardingDone, true);
  }

  Future<bool> isOnboardingCompleted() async {
    final p = await prefs;
    return p.getBool(_keyOnboardingDone) ?? false;
  }

  Future<int> getCoins() async {
    final p = await prefs;
    return p.getInt(_keyCoins) ?? 50; // Starting purse
  }

  Future<void> addCoins(int delta) async {
    final p = await prefs;
    final current = await getCoins();
    final updated = (current + delta).clamp(0, 9999999);
    await p.setInt(_keyCoins, updated);
  }

  Future<int> getDailyStreak() async {
    final p = await prefs;
    return p.getInt(_keyDailyStreak) ?? 0;
  }

  Future<void> incrementStreak() async {
    final p = await prefs;
    final current = await getDailyStreak();
    await p.setInt(_keyDailyStreak, current + 1);
  }

  Future<String?> getLastDailyDate() async {
    final p = await prefs;
    return p.getString(_keyLastDailyDate);
  }

  Future<void> setLastDailyDate(String date) async {
    final p = await prefs;
    await p.setString(_keyLastDailyDate, date);
  }

  Future<String> getThemeMode() async {
    final p = await prefs;
    return p.getString(_keyThemeMode) ?? 'dark'; // Dark mode default
  }

  Future<void> setThemeMode(String mode) async {
    final p = await prefs;
    await p.setString(_keyThemeMode, mode);
  }

  static const _keySoundEnabled = 'sound_effects_enabled';
  static const _keyHapticsEnabled = 'haptics_enabled';

  Future<bool> isSoundEnabled() async {
    final p = await prefs;
    return p.getBool(_keySoundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_keySoundEnabled, enabled);
  }

  Future<bool> isHapticsEnabled() async {
    final p = await prefs;
    return p.getBool(_keyHapticsEnabled) ?? true;
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_keyHapticsEnabled, enabled);
  }

  static const _keyCareerLeagueId = 'career_league_id';
  static const _keyCareerClubName = 'career_club_name';
  static const _keyCareerClubCode = 'career_club_code';
  static const _keyCareerIsCustomClub = 'career_is_custom_club';
  static const _keyCareerSquadMode = 'career_squad_mode';
  static const _keyCareerBudget = 'career_budget';
  static const _keyCareerSeason = 'career_season';
  static const _keyCareerGameweek = 'career_gameweek';
  static const _keyCareerTotalGameweeks = 'career_total_gameweeks';
  static const _keyCareerWinterBudgetAwarded = 'career_winter_budget_awarded';
  static const _keyCareerSquadIds = 'career_squad_ids';
  static const _keyCareerPlayerStats = 'career_player_stats';
  static const _keyCareerRecentResults = 'career_recent_results';
  static const _keyCareerLeagueScorers = 'career_league_scorers';
  static const _keyCareerLeagueTable = 'career_league_table';
  static const _keyCareerSeasonResults = 'career_season_results';
  static const _keyCareerFormationId = 'career_formation_id';
  static const _keyCareerUclTournament = 'career_ucl_tournament';
  static const _keyCareerPlayerAssists = 'career_player_assists';
  static const _keyCareerPlayerRatingsTotal = 'career_player_ratings_total';
  static const _keyCareerPlayerRatingsCount = 'career_player_ratings_count';
  static const _keyCareerLeagueAssists = 'career_league_assists';
  static const _keyCareerLeagueCleanSheets = 'career_league_clean_sheets';
  static const _keyCareerPrizeMoney = 'career_prize_money';
  static const _keyCareerLeagueClubRatingTotals = 'career_league_club_rating_totals';
  static const _keyCareerLeagueClubRatingCounts = 'career_league_club_rating_counts';
  static const _keyCareerRecentUclResults = 'career_recent_ucl_results';
  static const _keyCareerFaCupTournament = 'career_fa_cup_tournament';
  static const _keyCareerCarabaoCupTournament = 'career_carabao_cup_tournament';
  static const _keyCareerRecentFaCupResults = 'career_recent_fa_cup_results';
  static const _keyCareerRecentCarabaoResults = 'career_recent_carabao_results';
  static const _keyCareerPlayerRatingsOverride = 'career_player_ratings_override';
  static const _keyCareerPlayerAgesOverride = 'career_player_ages_override';
  static const _keyCareerPendingTransferOffers = 'career_pending_transfer_offers';
  static const _keyCareerActiveSquadEvents = 'career_active_squad_events';
  static const _keyCareerPlayerContracts = 'career_player_contracts';

  Future<Map<String, dynamic>?> getCareerConfig() async {
    final p = await prefs;
    final clubName = p.getString(_keyCareerClubName);
    if (clubName == null) return null;

    final statsRaw = p.getString(_keyCareerPlayerStats);
    Map<String, Map<String, int>> playerStats = {};
    if (statsRaw != null) {
      try {
        final decoded = jsonDecode(statsRaw) as Map<String, dynamic>;
        playerStats = decoded.map((k, v) {
          final inner = v as Map<String, dynamic>;
          return MapEntry(k, {
            'apps': (inner['apps'] as num?)?.toInt() ?? 0,
            'goals': (inner['goals'] as num?)?.toInt() ?? 0,
            'cleanSheets': (inner['cleanSheets'] as num?)?.toInt() ?? 0,
          });
        });
      } catch (_) {}
    }

    final resultsRaw = p.getString(_keyCareerRecentResults);
    List<Map<String, dynamic>> recentResults = [];
    if (resultsRaw != null) {
      try {
        final decoded = jsonDecode(resultsRaw) as List<dynamic>;
        recentResults = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final uclResultsRaw = p.getString(_keyCareerRecentUclResults);
    List<Map<String, dynamic>> recentUclResults = [];
    if (uclResultsRaw != null) {
      try {
        final decoded = jsonDecode(uclResultsRaw) as List<dynamic>;
        recentUclResults = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final faCupResultsRaw = p.getString(_keyCareerRecentFaCupResults);
    List<Map<String, dynamic>> recentFaCupResults = [];
    if (faCupResultsRaw != null) {
      try {
        final decoded = jsonDecode(faCupResultsRaw) as List<dynamic>;
        recentFaCupResults = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final carabaoResultsRaw = p.getString(_keyCareerRecentCarabaoResults);
    List<Map<String, dynamic>> recentCarabaoResults = [];
    if (carabaoResultsRaw != null) {
      try {
        final decoded = jsonDecode(carabaoResultsRaw) as List<dynamic>;
        recentCarabaoResults = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final scorersRaw = p.getString(_keyCareerLeagueScorers);
    Map<String, Map<String, dynamic>> leagueScorers = {};
    if (scorersRaw != null) {
      try {
        final decoded = jsonDecode(scorersRaw) as Map<String, dynamic>;
        leagueScorers = decoded.map((k, v) {
          final inner = v as Map<String, dynamic>;
          return MapEntry(k, {
            'club': inner['club'] as String? ?? '',
            'goals': (inner['goals'] as num?)?.toInt() ?? 0,
          });
        });
      } catch (_) {}
    }

    final tableRaw = p.getString(_keyCareerLeagueTable);
    List<Map<String, dynamic>> leagueTable = [];
    if (tableRaw != null) {
      try {
        final decoded = jsonDecode(tableRaw) as List<dynamic>;
        leagueTable = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final seasonResultsRaw = p.getString(_keyCareerSeasonResults);
    Map<int, List<Map<String, dynamic>>> seasonResults = {};
    if (seasonResultsRaw != null) {
      try {
        final decoded = jsonDecode(seasonResultsRaw) as Map<String, dynamic>;
        seasonResults = decoded.map((k, v) {
          final list = (v as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return MapEntry(int.parse(k), list);
        });
      } catch (_) {}
    }

    final uclRaw = p.getString(_keyCareerUclTournament);
    Map<String, dynamic>? uclTournament;
    if (uclRaw != null) {
      try {
        uclTournament = Map<String, dynamic>.from(jsonDecode(uclRaw) as Map);
      } catch (_) {}
    }

    final faCupRaw = p.getString(_keyCareerFaCupTournament);
    Map<String, dynamic>? faCupTournament;
    if (faCupRaw != null) {
      try {
        faCupTournament = Map<String, dynamic>.from(jsonDecode(faCupRaw) as Map);
      } catch (_) {}
    }

    final carabaoRaw = p.getString(_keyCareerCarabaoCupTournament);
    Map<String, dynamic>? carabaoCupTournament;
    if (carabaoRaw != null) {
      try {
        carabaoCupTournament = Map<String, dynamic>.from(jsonDecode(carabaoRaw) as Map);
      } catch (_) {}
    }

    final assistsRaw = p.getString(_keyCareerPlayerAssists);
    Map<String, int> playerAssists = {};
    if (assistsRaw != null) {
      try {
        final decoded = jsonDecode(assistsRaw) as Map<String, dynamic>;
        playerAssists = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final leagueAssistsRaw = p.getString(_keyCareerLeagueAssists);
    Map<String, int> leagueAssists = {};
    if (leagueAssistsRaw != null) {
      try {
        final decoded = jsonDecode(leagueAssistsRaw) as Map<String, dynamic>;
        leagueAssists = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final leagueCleanSheetsRaw = p.getString(_keyCareerLeagueCleanSheets);
    Map<String, int> leagueCleanSheets = {};
    if (leagueCleanSheetsRaw != null) {
      try {
        final decoded = jsonDecode(leagueCleanSheetsRaw) as Map<String, dynamic>;
        leagueCleanSheets = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final clubRatingTotalsRaw = p.getString(_keyCareerLeagueClubRatingTotals);
    Map<String, double> leagueClubRatingTotals = {};
    if (clubRatingTotalsRaw != null) {
      try {
        final decoded = jsonDecode(clubRatingTotalsRaw) as Map<String, dynamic>;
        leagueClubRatingTotals = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }

    final clubRatingCountsRaw = p.getString(_keyCareerLeagueClubRatingCounts);
    Map<String, int> leagueClubRatingCounts = {};
    if (clubRatingCountsRaw != null) {
      try {
        final decoded = jsonDecode(clubRatingCountsRaw) as Map<String, dynamic>;
        leagueClubRatingCounts = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final playerRatingsRaw = p.getString(_keyCareerPlayerRatingsOverride);
    Map<String, int> playerRatingsOverride = {};
    if (playerRatingsRaw != null) {
      try {
        final decoded = jsonDecode(playerRatingsRaw) as Map<String, dynamic>;
        playerRatingsOverride = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final playerAgesRaw = p.getString(_keyCareerPlayerAgesOverride);
    Map<String, int> playerAgesOverride = {};
    if (playerAgesRaw != null) {
      try {
        final decoded = jsonDecode(playerAgesRaw) as Map<String, dynamic>;
        playerAgesOverride = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    final offersRaw = p.getString(_keyCareerPendingTransferOffers);
    List<Map<String, dynamic>> pendingTransferOffers = [];
    if (offersRaw != null) {
      try {
        final decoded = jsonDecode(offersRaw) as List<dynamic>;
        pendingTransferOffers = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final eventsRaw = p.getString(_keyCareerActiveSquadEvents);
    List<Map<String, dynamic>> activeSquadEvents = [];
    if (eventsRaw != null) {
      try {
        final decoded = jsonDecode(eventsRaw) as List<dynamic>;
        activeSquadEvents = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final contractsRaw = p.getString(_keyCareerPlayerContracts);
    Map<String, int> playerContracts = {};
    if (contractsRaw != null) {
      try {
        final decoded = jsonDecode(contractsRaw) as Map<String, dynamic>;
        playerContracts = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    return {
      'leagueId': p.getString(_keyCareerLeagueId) ?? 'premier_league',
      'clubName': clubName,
      'clubCode': p.getString(_keyCareerClubCode) ?? 'MUN',
      'isCustomClub': p.getBool(_keyCareerIsCustomClub) ?? false,
      'squadMode': p.getString(_keyCareerSquadMode) ?? 'current',
      'budget': p.getDouble(_keyCareerBudget) ?? 85.0,
      'season': p.getInt(_keyCareerSeason) ?? 1,
      'gameweek': p.getInt(_keyCareerGameweek) ?? 1,
      'totalGameweeks': p.getInt(_keyCareerTotalGameweeks) ?? 38,
      'winterBudgetAwarded': p.getBool(_keyCareerWinterBudgetAwarded) ?? false,
      'squadIds': p.getStringList(_keyCareerSquadIds) ?? <String>[],
      'playerStats': playerStats,
      'recentResults': recentResults,
      'leagueScorers': leagueScorers,
      'leagueTable': leagueTable,
      'seasonResults': seasonResults,
      'formationId': p.getString(_keyCareerFormationId) ?? '4-3-3',
      'uclTournament': uclTournament,
      'playerAssists': playerAssists,
      'leagueAssists': leagueAssists,
      'leagueCleanSheets': leagueCleanSheets,
      'prizeMoney': p.getDouble(_keyCareerPrizeMoney) ?? 0.0,
      'leagueClubRatingTotals': leagueClubRatingTotals,
      'leagueClubRatingCounts': leagueClubRatingCounts,
      'recentUclResults': recentUclResults,
      'faCupTournament': faCupTournament,
      'carabaoCupTournament': carabaoCupTournament,
      'recentFaCupResults': recentFaCupResults,
      'recentCarabaoResults': recentCarabaoResults,
      'playerRatingsOverride': playerRatingsOverride,
      'playerAgesOverride': playerAgesOverride,
      'pendingTransferOffers': pendingTransferOffers,
      'activeSquadEvents': activeSquadEvents,
      'playerContracts': playerContracts,
    };
  }

  Future<void> saveCareerConfig({
    required String leagueId,
    required String clubName,
    required String clubCode,
    required bool isCustomClub,
    required String squadMode,
    double budget = 85.0,
    int season = 1,
    int gameweek = 1,
    int totalGameweeks = 38,
    bool winterBudgetAwarded = false,
    List<String> squadIds = const [],
    Map<String, Map<String, int>>? playerStats,
    List<Map<String, dynamic>>? recentResults,
    List<Map<String, dynamic>>? recentUclResults,
    List<Map<String, dynamic>>? recentFaCupResults,
    List<Map<String, dynamic>>? recentCarabaoResults,
    Map<String, Map<String, dynamic>>? leagueScorers,
    List<Map<String, dynamic>>? leagueTable,
    Map<int, List<Map<String, dynamic>>>? seasonResults,
    String? formationId,
    Map<String, dynamic>? uclTournament,
    Map<String, dynamic>? faCupTournament,
    Map<String, dynamic>? carabaoCupTournament,
    Map<String, int>? playerAssists,
    Map<String, int>? leagueAssists,
    Map<String, int>? leagueCleanSheets,
    double? prizeMoney,
    Map<String, double>? leagueClubRatingTotals,
    Map<String, int>? leagueClubRatingCounts,
    Map<String, int>? playerRatingsOverride,
    Map<String, int>? playerAgesOverride,
    List<Map<String, dynamic>>? pendingTransferOffers,
    List<Map<String, dynamic>>? activeSquadEvents,
    Map<String, int>? playerContracts,
  }) async {
    final p = await prefs;
    await p.setString(_keyCareerLeagueId, leagueId);
    await p.setString(_keyCareerClubName, clubName);
    await p.setString(_keyCareerClubCode, clubCode);
    await p.setBool(_keyCareerIsCustomClub, isCustomClub);
    await p.setString(_keyCareerSquadMode, squadMode);
    await p.setDouble(_keyCareerBudget, budget);
    await p.setInt(_keyCareerSeason, season);
    await p.setInt(_keyCareerGameweek, gameweek);
    await p.setInt(_keyCareerTotalGameweeks, totalGameweeks);
    await p.setBool(_keyCareerWinterBudgetAwarded, winterBudgetAwarded);
    await p.setStringList(_keyCareerSquadIds, squadIds);
    if (playerStats != null) {
      await p.setString(_keyCareerPlayerStats, jsonEncode(playerStats));
    }
    if (recentResults != null) {
      await p.setString(_keyCareerRecentResults, jsonEncode(recentResults));
    }
    if (recentUclResults != null) {
      await p.setString(_keyCareerRecentUclResults, jsonEncode(recentUclResults));
    }
    if (recentFaCupResults != null) {
      await p.setString(_keyCareerRecentFaCupResults, jsonEncode(recentFaCupResults));
    }
    if (recentCarabaoResults != null) {
      await p.setString(_keyCareerRecentCarabaoResults, jsonEncode(recentCarabaoResults));
    }
    if (leagueScorers != null) {
      await p.setString(_keyCareerLeagueScorers, jsonEncode(leagueScorers));
    }
    if (leagueTable != null) {
      await p.setString(_keyCareerLeagueTable, jsonEncode(leagueTable));
    }
    if (seasonResults != null) {
      final encodable = seasonResults.map((k, v) => MapEntry(k.toString(), v));
      await p.setString(_keyCareerSeasonResults, jsonEncode(encodable));
    }
    if (formationId != null) {
      await p.setString(_keyCareerFormationId, formationId);
    }
    if (uclTournament != null) {
      await p.setString(_keyCareerUclTournament, jsonEncode(uclTournament));
    }
    if (faCupTournament != null) {
      await p.setString(_keyCareerFaCupTournament, jsonEncode(faCupTournament));
    }
    if (carabaoCupTournament != null) {
      await p.setString(_keyCareerCarabaoCupTournament, jsonEncode(carabaoCupTournament));
    }
    if (playerAssists != null) {
      await p.setString(_keyCareerPlayerAssists, jsonEncode(playerAssists));
    }
    if (leagueAssists != null) {
      await p.setString(_keyCareerLeagueAssists, jsonEncode(leagueAssists));
    }
    if (leagueCleanSheets != null) {
      await p.setString(_keyCareerLeagueCleanSheets, jsonEncode(leagueCleanSheets));
    }
    if (prizeMoney != null) {
      await p.setDouble(_keyCareerPrizeMoney, prizeMoney);
    }
    if (leagueClubRatingTotals != null) {
      await p.setString(_keyCareerLeagueClubRatingTotals, jsonEncode(leagueClubRatingTotals));
    }
    if (leagueClubRatingCounts != null) {
      await p.setString(_keyCareerLeagueClubRatingCounts, jsonEncode(leagueClubRatingCounts));
    }
    if (playerRatingsOverride != null) {
      await p.setString(_keyCareerPlayerRatingsOverride, jsonEncode(playerRatingsOverride));
    }
    if (playerAgesOverride != null) {
      await p.setString(_keyCareerPlayerAgesOverride, jsonEncode(playerAgesOverride));
    }
    if (pendingTransferOffers != null) {
      await p.setString(_keyCareerPendingTransferOffers, jsonEncode(pendingTransferOffers));
    }
    if (activeSquadEvents != null) {
      await p.setString(_keyCareerActiveSquadEvents, jsonEncode(activeSquadEvents));
    }
    if (playerContracts != null) {
      await p.setString(_keyCareerPlayerContracts, jsonEncode(playerContracts));
    }
  }

  Future<void> clearCareerConfig() async {
    final p = await prefs;
    await p.remove(_keyCareerLeagueId);
    await p.remove(_keyCareerClubName);
    await p.remove(_keyCareerClubCode);
    await p.remove(_keyCareerIsCustomClub);
    await p.remove(_keyCareerSquadMode);
    await p.remove(_keyCareerBudget);
    await p.remove(_keyCareerSeason);
    await p.remove(_keyCareerGameweek);
    await p.remove(_keyCareerTotalGameweeks);
    await p.remove(_keyCareerWinterBudgetAwarded);
    await p.remove(_keyCareerSquadIds);
    await p.remove(_keyCareerPlayerStats);
    await p.remove(_keyCareerRecentResults);
    await p.remove(_keyCareerRecentUclResults);
    await p.remove(_keyCareerRecentFaCupResults);
    await p.remove(_keyCareerRecentCarabaoResults);
    await p.remove(_keyCareerLeagueScorers);
    await p.remove(_keyCareerLeagueTable);
    await p.remove(_keyCareerSeasonResults);
    await p.remove(_keyCareerFormationId);
    await p.remove(_keyCareerUclTournament);
    await p.remove(_keyCareerFaCupTournament);
    await p.remove(_keyCareerCarabaoCupTournament);
    await p.remove(_keyCareerPlayerAssists);
    await p.remove(_keyCareerPlayerRatingsTotal);
    await p.remove(_keyCareerPlayerRatingsCount);
    await p.remove(_keyCareerLeagueAssists);
    await p.remove(_keyCareerLeagueCleanSheets);
    await p.remove(_keyCareerPrizeMoney);
    await p.remove(_keyCareerLeagueClubRatingTotals);
    await p.remove(_keyCareerLeagueClubRatingCounts);
    await p.remove(_keyCareerPlayerRatingsOverride);
    await p.remove(_keyCareerPlayerAgesOverride);
    await p.remove(_keyCareerPendingTransferOffers);
    await p.remove(_keyCareerActiveSquadEvents);
    await p.remove(_keyCareerPlayerContracts);
  }
}
