# Pre-Fix 19: Career Overhaul & Game Polish — Implementation Plan

This plan covers **10 sequential fixes (Fix 18a through 18j)**, each verified with `flutter analyze` + `flutter test` + APK build before moving to the next. A final **Fix 19 (Verification & Polish)** is appended.

---

## Open Questions

> [!IMPORTANT]
> **Q1: Premier League 20 teams — which 10 to add?**
> The database has these English club teams with modern rosters (season ≥ 2022): Bournemouth, Brentford, Brighton, Burnley, Crystal Palace, Everton, Fulham, Ipswich Town, Leeds United, Leicester City, Liverpool, Luton Town, Man City, Man United, Newcastle, Norwich City, Nottingham Forest, Sheffield United, Southampton, Sunderland, Tottenham, Watford, West Ham, Wolverhampton Wanderers + the current 10 (Arsenal, Aston Villa, Chelsea).
>
> **Proposed 20-club Premier League roster:**
> Arsenal, Aston Villa, AFC Bournemouth, Brentford, Brighton & Hove Albion, Burnley, Chelsea, Crystal Palace, Everton, Fulham, Liverpool, Manchester City, Manchester United, Newcastle United, Nottingham Forest, Tottenham Hotspur, West Ham United, Wolverhampton Wanderers, Ipswich Town, Leicester City
>
> Does this look right, or do you want different clubs?

> [!IMPORTANT]
> **Q2: UCL — which teams qualify, and how does it integrate?**
> You mentioned "other competitions such as UCL". The simplest approach is:
> - At season start, the **top 4 clubs** from the previous season's league table (or a seeded pot of 8 elite clubs for Season 1) enter a simplified **UCL Group Stage → Knockout** tournament running in parallel with league fixtures.
> - UCL matches are played on separate "midweek" matchdays interspersed between league gameweeks.
> - Stats are tracked separately per competition.
>
> Is this the right scope, or do you want a full 32/36-team UCL simulation?

> [!IMPORTANT]
> **Q3: Connections — ad-based hints**
> Currently the Connections game ("Four by Four") already shows a "One away!" SnackBar when 3/4 match. You want:
> 1. Free hint showing how many from each group are selected (e.g., "2 from the same group!")
> 2. Ad-gated hint revealing the category name of the group with the most selected players.
>
> Is that the right interpretation?

> [!IMPORTANT]
> **Q4: Other leagues — should they also expand to 20 clubs?**
> Currently there are 5 leagues with 10 clubs each. Should Continental Elite, Champions Invitational, English Championship, and European Heritage also expand to 20? Or just Premier League for now?

---

## Fix 18a — Premier League: 20 Teams with Full 38-Game H/A Schedule

### The Problem
The Premier League only has 10 clubs, producing 5 matches per gameweek. A real PL has 20 clubs with 38 gameweeks (each team plays every other team home and away = 19×2 = 38 matches, with 10 matches per gameweek).

### Proposed Changes

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Expand `kAvailableLeagues[0]` (`premier_league`) from 10 → 20 clubs, adding: AFC Bournemouth, Brentford, Brighton, Burnley, Crystal Palace, Everton, Fulham, Leicester City, Nottingham Forest, Wolverhampton Wanderers (+ their club codes).
- The `generateSeasonSchedule()` function already uses the Berger circle method for n clubs, so it will automatically produce 19 base rounds (single round-robin) and mirror them for the return leg, yielding 38 gameweeks with 10 matches each — **no algorithm changes needed**.
- Update `TransferWindowState.compute()` — the winter window timing stays at GW 19-21 (2 gameweeks = "2 weeks" as requested in Fix 18b).
- Update roster loading in `_launchCareer()` and AI squad pre-caching to handle 20 clubs.

#### [MODIFY] [career_test.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/test/career_test.dart)
- Update the test `'All 5 available leagues are properly configured with 10 clubs each'` — the PL now has 20.
- Add test verifying 38 gameweeks × 10 matches per GW = 380 total fixtures.

---

## Fix 18b — Winter Transfer Window: 2 Gameweeks Only

### The Problem
Currently the winter window spans GW 19–23 (5 gameweeks). The user wants it open for exactly 2 gameweeks ("2 weeks i.e. 2 matches of weekdays") after the halfway point (GW 19).

### Proposed Changes

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Change `TransferWindowState.compute()` for 38 GW mode: Winter window = GW 20–21 (2 gameweeks). The summer window stays GW 1–4.
- For 18 GW sprint mode: Winter window = GW 10–11 (2 gameweeks). Summer stays GW 1–3.

---

## Fix 18c — UCL Competition (Champions League Simulation)

### The Problem
There is only a domestic league. The user wants additional competition(s), specifically the Champions League, with separate stats tracking.

### Proposed Changes

#### [NEW] [lib/domain/services/ucl_engine.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/domain/services/ucl_engine.dart)
- `UclTournament` class managing a simplified 8-team UCL:
  - **Group Stage:** 2 groups of 4 teams, each team plays 6 matches (home & away vs 3 group opponents). Run across GW 1–12 of the league season (1 UCL match every ~2 league GWs).
  - **Knockout Stage:** Top 2 from each group → Semi-Finals (2 legs) → Final (1 match).
  - Uses `SimEngine` for match simulation.
  - Separate `UclMatchResult` and `UclTableEntry` with serialization.
- Season 1 seed pot: top 8 from a curated list of elite European clubs (Real Madrid, Man City, Bayern Munich, Barcelona, Liverpool, PSG, Inter Milan, Juventus — or the top 4 from the user's league + 4 seeded European giants).

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Add UCL state tracking (`_uclTournament`, `_uclResults`, `_uclPlayerGoals`, etc.).
- In `_simMatchday()`, also simulate UCL fixtures on appropriate gameweeks.
- Add a third tab in standings: `[ LEAGUE TABLE ] | [ GOLDEN BOOT ] | [ UCL ]`.
- Separate UCL stats from league stats.

---

## Fix 18d — FIFA-Style Formation Editor (4-3-3 default + alternatives)

### The Problem
There is no formation system. Players are just listed in positional order. The user wants a visual pitch formation view like FIFA where players can be arranged in tactical shapes.

### Proposed Changes

#### [NEW] [lib/features/career/formation_editor.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/formation_editor.dart)
- Define `Formation` enum/class with preset shapes:
  - `4-3-3` (default), `4-4-2`, `4-2-3-1`, `3-5-2`, `3-4-3`, `5-3-2`, `5-4-1`, `4-1-4-1`, `4-5-1`
  - Each formation defines slot positions on a normalized pitch coordinate grid (x: 0.0–1.0, y: 0.0–1.0).
- `FormationEditorSheet` — a modal bottom sheet showing:
  - A bird's-eye pitch view (green gradient rectangle with white pitch markings).
  - Player dots at their formation positions, draggable to swap slots.
  - Formation selector dropdown/chips at the top.
  - Player name labels + OVR ratings on each dot.
  - Tap a slot to see player details or swap with bench.
- The selected formation is persisted in `PrefsService` and displayed on the career dashboard.

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Add `_currentFormation` state field (default `'4-3-3'`).
- Add formation display card on the career dashboard showing the 11 starters in tactical shape.
- Wire formation selector to persist and restore.

---

## Fix 18e — Realistic Goal Scoring Distribution (Position-Weighted)

### The Problem
Currently `_generateGoalEvents()` picks scorers uniformly at random from the squad list: `squad[_rng.nextInt(squad.length)]`. This means goalkeepers score as often as strikers.

### Proposed Changes

#### [MODIFY] [sim_engine.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/domain/services/sim_engine.dart)
- Change `simulateMatch()` signature to accept `List<Map<String, dynamic>> homeSquadInfo` containing `{name, position, overall}` for each player (instead of just `List<String>`).
- Implement **position-weighted scorer selection**:
  - `ST/CF`: weight 40
  - `LW/RW`: weight 25
  - `CAM`: weight 15
  - `CM/LM/RM`: weight 8
  - `CDM`: weight 4
  - `CB/LB/RB/LWB/RWB`: weight 2
  - `GK`: weight 0.2 (effectively ~0.1% chance)
  - Within each position group, higher-rated players get a bonus multiplier: `weight * (overall / 80.0)`.
- Penalty goals (~10% chance) bypass position weighting — any outfield player can take a penalty (but prefer designated takers: highest-rated forward or midfielder).
- Own goals (~3% chance per match) assign scorer from the *opposing* side's defenders.

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Update all calls to `simulateMatch()` to pass squad info with positions and ratings instead of just names.
- For AI squads, include cached position data.

---

## Fix 18f — Half-Time Substitutions (Random & Logical)

### The Problem
No substitutions happen during simulated matches. The user wants subs after ~50–60 minutes, randomly but logically.

### Proposed Changes

#### [MODIFY] [sim_engine.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/domain/services/sim_engine.dart)
- Add `SubstitutionEvent` class: `{playerOut, playerIn, minute}`.
- Add `List<SubstitutionEvent> homeSubstitutions` and `awaySubstitutions` to `MatchResult`.
- In `simulateMatch()`:
  - Each team makes 1–3 substitutions between minutes 46–80.
  - Sub logic: lower-rated starters are more likely to be subbed; subs come from the bench (positions 12–18).
  - Position-aware: prefer like-for-like swaps (DEF↔DEF, MID↔MID, FWD↔FWD).
  - After substitution, goals scored post-sub use the updated squad (subs can score).

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Track sub appearances in `_playerAppearances` (sub-on players get a partial appearance).
- Display substitutions in match detail (Fix 18h).

---

## Fix 18g — Comprehensive Stats: Assists, Clean Sheets, Ratings & Team Stats

### The Problem
Only Golden Boot (goals) is tracked. The user wants assists, clean sheets, average player ratings, and team-level stats, all tracked per competition.

### Proposed Changes

#### [MODIFY] [sim_engine.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/domain/services/sim_engine.dart)
- Add `assisterName` to `GoalEvent` (nullable — some goals have no assist).
- Generate assists: ~70% of non-penalty goals get an assist from a teammate (weighted by CAM/CM/LW/RW positions).
- Add per-player match rating generation (6.0–10.0 scale based on goals, assists, clean sheets, and random variance).

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Track per-player: goals, assists, clean sheets, total rating points, appearances.
- Track per-team: goals scored, goals conceded, clean sheets, average rating.
- Add stats tabs: `[ LEAGUE TABLE ] | [ GOLDEN BOOT ] | [ ASSISTS ] | [ CLEAN SHEETS ] | [ TEAM STATS ]` — or a single "STATS" tab with sub-sections.
- Separate league stats from UCL stats (if Fix 18c is implemented).
- Persist all new stats in `PrefsService` and `SaveService`.

---

## Fix 18h — Tappable Match Detail Sheet (Post-Match Report)

### The Problem
Completed matches show only the scoreline. The user wants to tap a match to see full post-match detail: scorers, player ratings, substitutions, etc.

### Proposed Changes

#### [NEW] [lib/features/career/match_detail_sheet.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/match_detail_sheet.dart)
- `MatchDetailSheet` — a rich modal bottom sheet showing:
  - Match header: club crests, final score, competition badge, attendance.
  - Timeline: chronological goal events with scorer names, minutes, and assist names.
  - Substitutions timeline with minute stamps.
  - Player ratings table: two-column layout (home vs away) with ratings color-coded (green 7+, yellow 6–7, red <6).
  - Man of the Match highlight (highest-rated player).
  - Team stats comparison bar: possession (simulated %), shots, fouls, corners.

#### [MODIFY] [career_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/career/career_screen.dart)
- Make all match result tiles tappable (`onTap: () => showMatchDetailSheet(...)`)
- Also wire tappable matches in `SeasonScheduleSheet`.

---

## Fix 18i — Connections "Four by Four": Hints System

### The Problem
The Connections game currently only shows "One away!" on a wrong guess with 3/4 matching. The user wants:
1. Progressive hints when 2+ from the same group are selected.
2. Ad-gated hints revealing category information.

### Proposed Changes

#### [MODIFY] [connections_screen.dart](file:///c:/Users/Ayaan/Downloads/Video/Football/lib/features/connections/connections_screen.dart)
- **Free progressive hints during selection:**
  - When the user selects 2+ players and taps "Submit" incorrectly:
    - If 2/4 match a group: "Two from the same group!"
    - If 3/4 match a group: "One away! 3 of these belong together." (existing)
  - Also show a live indicator during selection (before submit): "2 selected from the same group" as a subtle chip when applicable.
- **Ad-gated category hint:**
  - Add a "Hint" button (limited to 1 per game).
  - Tapping shows the mock rewarded ad dialog (same as Identikit).
  - After watching: reveals the **category title** of the easiest remaining unsolved group (tier 1 first, then tier 2, etc.).
  - E.g., "HINT: One group is 'ICONIC SHIRT #7 WEARERS'".

---

## Fix 18j — Verification & Polish Pass

### Scope
- Run `flutter analyze` — must be 0 issues.
- Run `flutter test` — must be 100% pass.
- Build release APK.
- Deploy to `C:\Users\Ayaan\Desktop\Touchline.apk`.
- Verify all new features work together.
- Edge case checks: empty squads, mid-season save/restore with 20-team tables, UCL bracket after season advance, formation persistence across sessions.

---

## Verification Plan

### Automated Tests
Each fix adds targeted tests:
- **18a:** 20-club schedule balance (380 fixtures, 19H/19A per club).
- **18b:** Winter window exactly GW 20–21.
- **18c:** UCL group stage fixture count, knockout bracket generation.
- **18d:** Formation coordinate validation for all presets.
- **18e:** Scorer distribution: GK goals < 1% over 1000 simulations.
- **18f:** Substitution events generated (1–3 per team, valid minutes).
- **18g:** Assists tracked, clean sheets accumulated, ratings in [6.0, 10.0].
- **18h:** MatchDetailSheet renders without errors.
- **18i:** Connections hint logic correctness.

### Manual Verification
- Build and deploy APK after each fix.
- User tests on Android device.

---

## Execution Order

| Fix | Description | Dependencies |
|-----|-------------|-------------|
| 18a | 20-team Premier League | None |
| 18b | Winter window 2 GWs | 18a |
| 18c | UCL competition | 18a |
| 18d | Formation editor | None (parallel-safe) |
| 18e | Realistic goal scoring | None |
| 18f | Substitutions | 18e |
| 18g | Comprehensive stats (assists, CS, ratings) | 18e, 18f |
| 18h | Tappable match detail sheet | 18f, 18g |
| 18i | Connections hints | None (parallel-safe) |
| 18j | Verification & polish | All above |
