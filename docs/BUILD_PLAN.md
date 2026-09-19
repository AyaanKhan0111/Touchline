# BUILD PLAN — "TOUCHLINE"

*Based on data audit and feasibility analysis*
*Section 0.4 deliverable*

---

## Executive Summary

The database contains **24,651 player-roster instances** across **11,723 unique players**, covering the Premier League (1994–2026), European leagues (1994–2026), and World Cup national teams (1966–2022), plus EA FC 25/26/27 snapshots. Core data (names, ratings, 6 attribute stats, positions, clubs) is at 100% coverage. The database is **strong for attribute-based and squad-based modes** but **lacks career statistics** (goals, assists, appearances), **transfer history**, **nationality for club players**, **preferred foot**, and **height/weight**.

Of the 20 proposed game modes, **8 are GO**, **9 are DEGRADE** (buildable with reduced rulesets), and **3 are DEFER**.

---

## Section 0.3 — Derived Data Layer (Precompute Pipeline)

A build-time pipeline (`tool/precompute.py` or `tool/precompute.dart`) will generate compact asset files shipped with the app. These run **at build time, not runtime**.

### Indices to generate

| Index | Description | Source Logic | Output Format |
|---|---|---|---|
| `club_alumni_index` | clubCode → Set(playerId) | Group All Players Master by Team Code, collect unique Player IDs | JSON: `{ "MUN": [7826, 167397, ...], ... }` |
| `nation_index` | nationCode → Set(playerId) | From Nations Cup sheet: group by Team Code | JSON: `{ "ARG": ["P-00855", ...], ... }` |
| `position_index` | position → Set(playerId) | Group by Primary Position across all players | JSON: `{ "ST": [7826, ...], ... }` |
| `decade_index` | decade → Set(playerId) | Group by `floor(season/10)*10` | JSON: `{ "2010": [...], ... }` |
| `league_index` | mode → Set(playerId) | Group by Mode | JSON |
| `club_season_roster` | squadId → List(player) | Group by Squad ID with full player data | JSON (for XI modes) |
| `rating_band_index` | ratingBand → Set(playerId) | Bucket OVR into bands: 85+, 80-84, 75-79, etc. | JSON |
| `age_band_index` | ageBand → Set(playerId) | Under 21, 21-25, 26-30, 31-35, Over 35 | JSON |
| `category_cardinality` | For each puzzle category: how many valid answers | Count per category combination | JSON |
| `answer_popularity` | Per player: "obviousness" score | `(OVR/100)^2 × leaguePrestigeFactor × recencyFactor` | JSON: `{ "158023": 0.94, ... }` |
| `market_value_curve` | Per player: derived transfer value | §6.4 formula using OVR, age, position | JSON: `{ "158023": 185.2, ... }` (£m) |
| `player_search_index` | FTS-ready: name → playerId with aliases | Normalize names, generate search tokens | SQLite FTS5 table |
| `puzzle_bank` | Pre-generated, validated puzzles per mode | Mode-specific generators with validators | JSON per mode |
| `name_unification` | Canonical name per Player ID | Resolve the 198 multi-name IDs to one display name | JSON: `{ "5471": "Frank Lampard", ... }` |
| `nationality_crossref` | Club-mode player → inferred nationality | Match club-mode player names to Nations Cup team membership | JSON: `{ "158023": "ARG", ... }` |

### League prestige factors (for popularity scoring)

| League Context | Prestige Factor |
|---|---|
| EA FC 27 | 1.0 |
| EA FC 26 | 0.95 |
| EA FC 25 | 0.90 |
| Premier League (modern, 2015+) | 0.85 |
| European League (modern, 2015+) | 0.85 |
| Premier League (classic, <2015) | 0.65 |
| European League (classic, <2015) | 0.65 |
| Nations Cup (modern, 2006+) | 0.75 |
| Nations Cup (classic, <2006) | 0.50 |

### Pipeline architecture

```
tool/precompute.py
  ├── load_master_data()          # Read Excel → pandas
  ├── fix_data_integrity()        # Fix ID 20801 collision, unify names
  ├── build_indices()             # All index maps
  ├── compute_popularity()        # Obviousness scores
  ├── compute_market_values()     # §6.4 formula
  ├── crossref_nationality()      # Name-match club players to NC teams
  ├── generate_puzzle_bank()      # Per-mode puzzle generators
  │   ├── generate_grid_puzzles()
  │   ├── generate_bingo_boards()
  │   ├── generate_connections()
  │   ├── generate_identikit()
  │   └── generate_quiz_questions()
  ├── validate_puzzles()          # Solvability, non-triviality, difficulty
  └── export_assets()             # Write to assets/db/ as SQLite + JSON
```

### Output asset budget

| Asset | Estimated Size |
|---|---|
| `players.db` (SQLite with FTS5) | ~4 MB |
| `indices.json` (all indices, compressed) | ~1.5 MB |
| `puzzle_bank.json` (all pre-generated puzzles) | ~2 MB |
| `popularity.json` | ~0.3 MB |
| **Total** | **~8 MB** |

If over 8 MB: switch indices to SQLite tables (more query-efficient, same disk footprint).

---

## Phased Build Plan

### Phase 0 — Audit ✅ (THIS DOCUMENT)
**Deliverables:**
- [x] `docs/DATA_REPORT.md` — complete schema, coverage, distributions, integrity, red flags
- [x] `docs/MODE_FEASIBILITY.md` — per-mode verdict with degradation plans
- [x] `docs/BUILD_PLAN.md` — this document

**DEFER items recorded:**
- Goal Chase (§5.7) — needs career goals/assists/appearances
- Transfer Deadline (§5.14.2) — needs transfer fee data
- Retro Rewind (§5.14.8) — needs historical league standings

**STOP: Review all three documents before proceeding.**

---

### Phase 1 — Foundation
**Goal:** App shell with theme, routing, DB ingestion, search, and onboarding.

| Task | Details |
|---|---|
| Flutter project setup | Android-only, min SDK 24, Dart 3, folder structure per §2 |
| Design system | `core/theme` with exact palette from §3, Inter font bundle, tabular figures, spacing grid |
| Dark mode | First-class, system-default |
| DB ingestion | Run precompute pipeline → ship SQLite + JSON in `assets/db/`. Copy to app dir on first run. |
| FTS5 search index | Player name search <80ms over 24k rows, fuzzy, accent-insensitive |
| Player search widget | Shared component: debounce 120ms, ranked by rating + league prestige |
| Manager name onboarding | Single screen, no tutorial, stores globally |
| Hub shell | Daily Hub layout (placeholder tiles for modes) |
| Routing | `go_router` with predictable back-stack |
| `/debug` screen | Dumps DB stats, player counts, index health |
| State management | Riverpod (consistent throughout) |
| Save data layer | `save.db` (writable SQLite) + `shared_preferences` for settings/streaks |

**Estimated effort:** 2–3 weeks

---

### Phase 2 — Puzzle Engine + 3 Modes
**Goal:** Shared puzzle infrastructure, then Grid, Identikit, and Higher-or-Lower end-to-end.

| Task | Details |
|---|---|
| Timer widget | Thin linear bar, shared |
| Result sheet | Score, time, coins earned, shareable text summary, play again |
| Daily vs Endless | Seeded daily puzzle + unlimited random |
| Streak tracking | Per-mode daily streak counter |
| Coin ledger | In-memory + persisted to save.db |
| **Grid** | 3×3, degraded category set (club × position × league × rating × age × GK), rarity scoring, 9 guesses |
| **Identikit** | 6 clues (position → league → age → rating → club), Wordle-style comparison feedback, 3 difficulty tiers |
| **Higher or Lower** | 8 stat categories (OVR + 6 attrs + age), endless streak, personal best |
| Puzzle bank generation | Grid + Identikit + H/L puzzles pre-generated and validated |

**Estimated effort:** 3–4 weeks

---

### Phase 3 — Remaining Puzzle Modes
**Goal:** All viable puzzle modes live, Daily Hub with Full Card.

| Task | Details |
|---|---|
| **Bingo** | 5×5, ~15 criteria from available data, timed + casual, partial credit |
| **Connections** | 16 names, 4 groups (club/position/league/rating/age/shirt#), trap players, colour-coded difficulty |
| **Guess the XI** | "Best XI of [Club] [Year]" from squad data, pitch silhouettes, letter-count hints |
| **Build the XI** | Formation picker, Eleven Clubs / Alphabet XI / Decade XI variants. Eleven Nations restricted to NC pool. Budget XI with derived values. |
| **Quiz** | 4 difficulty tiers, ~15 question templates, MCQ + true/false + ranking + odd-one-out, distractor quality rules |
| **Build-a-Player** | 5 random players → pick one attribute each → composite rating, Lab collection, weekly challenge |
| **Career Path** | Timeline of clubs for multi-club players (~1,077 player pool) |
| **Stat Attack** | Top Trumps with 6 attrs + OVR, best of 9 |
| **Daily Hub** | Fixture list of today's challenges, Full Card bonus (25 coins), streak calendar |

**Estimated effort:** 4–5 weeks

---

### Phase 4 — Simulation Engine
**Goal:** Pure Dart sim engine, fully tested, with Tournament Lab as test harness.

| Task | Details |
|---|---|
| Team strength calculator | Attack/defence from player attrs + position weights + form + stamina |
| Expected goals model | Poisson distribution, home advantage, tactic modifiers, clamped xG |
| Goal/assist attribution | Weighted random draw by position × overall × form |
| Match ratings | §6.5 rating system, 6.0 base, all modifiers, 3.5–10.0 clamp |
| Event simulation | Injuries, fatigue, cards, suspensions |
| Match stats | Possession, shots, xG, corners, fouls — all derived consistently |
| Seeded RNG | `Random(seed)` for reproducibility |
| **10,000-match validation suite** | 85-rated vs 70-rated: expect 72–80% wins. Full 38-game season: champion 80–95 pts. Unit tests. |
| **Tournament Lab** | Run any competition (domestic, continental, custom cup), full bracket/table, match detail, speed control, re-run with new seed |

**Estimated effort:** 3–4 weeks

---

### Phase 5 — Career Mode
**Goal:** Full 15-season campaign, squad management, transfers, match day, stats.

| Task | Details |
|---|---|
| Career onboarding | Take a job / Found a club / Random XI |
| Squad management | 20–24 players, formation picker, auto-best-XI, position suitability |
| Season structure | League + National Cup + League Cup + Continental + Season Shield |
| Fixture generation | Full double round-robin + cup draws |
| Match day UX | Pre-match screen, 3 sim speeds, result card (§6.6 exact spec), match detail sheet with 4 tabs |
| League table | Full spec with tiebreakers, zone markers |
| Cup brackets | Horizontally scrollable, every tie tappable |
| Stats hub | Player stats, team stats, leaderboards per competition + aggregated |
| Transfer system | Valuation formula (§6.4), 2-window system, AI negotiation, wage budget |
| Between-match events | Injuries, fatigue recovery, morale, hot streaks, suspensions, inbox |
| Board & objectives | Confidence meter, seasonal targets, sack logic, reputation |
| Season rollover | Age progression, contract expiry, retired players, new season finances |
| Season review | Team of Season, Player of Season, record book, trophy cabinet |
| Save/load | Autosave after every action, crash recovery, save versioning |
| Hall of records | 15-season career aggregate stats |

**Estimated effort:** 6–8 weeks

---

### Phase 6 — Economy & Ads
**Goal:** Coin economy live, AdMob behind feature flags.

| Task | Details |
|---|---|
| Coin ledger | All faucets and sinks from §7.2, persisted |
| Rewarded ad placements | Per-mode hooks from §5.x |
| `AdService` interface | `NoOpAdService` for dev, `AdMobService` for release |
| Feature flags | `RemoteConfigless FeatureFlags` class |
| Interstitial rules | Max 1 per 180s, max 12/day, natural boundaries only |
| Banner placement | Hub/menu and squad-list only |
| `remove_ads` IAP stub | Stubbed, not wired |
| Tuning pass | Target 60–90 coins/day for daily-active player |

**Estimated effort:** 1–2 weeks

---

### Phase 7 — Polish
**Goal:** Section 9 checklist complete, ready for store.

| Task | Details |
|---|---|
| Tabular figures audit | Every number in every table |
| Accent audit | Max one accent element per screen |
| Empty states | Written copy for every empty state |
| Loading skeletons | Match final layout |
| Destructive action confirms | Abandon career, reset streak |
| Back button audit | Every screen, including mid-puzzle |
| Haptics | Light (correct), medium (wrong), selection click |
| Light + dark mode screenshots | Every screen |
| Performance pass | Cold start <2s, season sim <3s, search <80ms |
| Accessibility | Text scaling 200%, semantic labels, no colour-only info, 48dp touch targets |
| Localisation-ready | All strings through `AppStrings` layer |
| App icon + store assets | — |

**Estimated effort:** 2–3 weeks

---

## DEFER Backlog

| Mode | What's needed | Priority |
|---|---|---|
| Goal Chase (§5.7) | `career_goals`, `career_assists`, `career_appearances` per player | HIGH — the mode is described as "the addictive one" |
| Transfer Deadline (§5.14.2) | Transfer fee, year, from/to club per transfer | MEDIUM |
| Retro Rewind (§5.14.8) | Historical league final standings (position, points, GD) | LOW |
| Grid categories: "scored 100+ goals", "left-footed", "won trophy" | Career goals, preferred foot, trophy data | MEDIUM — enriches an already-shippable mode |
| Bingo criteria: height-based, trophy-based, captain, one-club | Height, trophies, captain flag, transfer count | MEDIUM |
| Build the XI: "Eleven Nations" for full DB | Nationality column for club-mode players | HIGH — dramatically expands this mode |
| Identikit: preferred foot clue | Preferred foot | LOW |

---

## Open Questions → `docs/OPEN_QUESTIONS.md`

1. **Player ID collision (20801 = Cristiano Ronaldo AND Harry Kane):** Which is correct? Likely Ronaldo owns the FIFA ID. Harry Kane may be a data entry error. Need manual verification — should we default to keeping Ronaldo and assigning Kane a new synthetic ID?

2. **198 players with multiple name variants** (e.g., "F. Lampard" vs "Frank Lampard"): The precompute pipeline will pick the **longest/most complete name** as the canonical display name. Is that acceptable, or do you prefer abbreviated forms ("F. Lampard")?

3. **76 duplicate player-season-mode entries** (e.g., Sánchez at both Man Utd and Arsenal in 2018): These represent mid-season transfers and are **legitimate data**. Both entries should be kept, as they are useful for club alumni indices. Confirm this interpretation?

4. **EA FC 25/26/27 data** — these are separate from the Premier League / European League modes and contain modern squads. Should Career mode prioritize the **latest snapshot** (FC 27 for 2027, FC 26 for 2026) as the "current" data, with historical PL/Euro data for career history and puzzle breadth?

5. **Nations Cup players have no age data.** For modes that filter by age, should we: (a) exclude Nations Cup players from age-based puzzles entirely, or (b) attempt to infer ages from tournament year and known birth years (requires external data)?

6. **Squad size in DB averages ~30 per team-season**, but Career mode specifies 20–24. Should we trim squads to 24 (by OVR, keeping positional balance) when initializing a career, and store the trimmed players in a "free agent" pool?

---

## Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| DB lacks career stats — 3 modes deferred | Reduces launch content | The 17 non-deferred modes provide strong launch content. Goal Chase data could be sourced later. |
| Nationality only available for ~35% of players | Limits geographic puzzle categories | Cross-reference pipeline (name match NC ↔ club) will extend coverage. Consider adding a nationality CSV overlay. |
| Player ID collisions (198 multi-name, 1 multi-player) | Search and puzzle accuracy | Precompute pipeline resolves all collisions before asset generation. |
| Squad Rating Weight missing for 37.6% | Affects Tournament Lab balance | Compute from squad OVR average as fallback. |
| 5.4 MB Excel file → asset size | App install size | SQLite + compression targets <8 MB for all assets. |
