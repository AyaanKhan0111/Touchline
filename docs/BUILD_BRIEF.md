<USER_REQUEST>
# BUILD BRIEF — "TOUCHLINE" (working title will most likely change to something else)
## An offline Flutter/Android football knowledge + management game

> **How to use this file:** paste Section 0 first and let the agent complete the Data Audit before it writes a single screen. Then paste the rest. Do not let it skip Section 0 — half the modes below depend on fields that may or may not exist in the bundled database.

---

# SECTION 0 — MANDATORY FIRST TASK: DATA AUDIT & FEASIBILITY PLAN

**Do not write any UI, game logic, or Flutter code yet.**

You have a local player database bundled with this project(Football_Database_Expanded.xlsx). Before anything else:

### 0.1 Profile the data
Write a throwaway Dart or Python script (`tool/data_audit.dart` or `tool/audit.py`) that walks the entire database and emits `docs/DATA_REPORT.md` containing:

1. **Schema dump** — every table/collection, every field, inferred type, sample of 5 values.
2. **Row counts** — total players, clubs, leagues, nations, seasons.
3. **Coverage table** — for *every* field: `% non-null`, `% empty string`, `distinct count`, `min/max` for numerics.
4. **Distribution checks** — players per league, players per club, players per nation, rating histogram (buckets of 5), age histogram, position counts.
5. **Relational integrity** — orphaned club IDs, players with no league, clubs with no players, duplicate player names, duplicate IDs.
6. **Career-history depth** — does the DB contain *previous clubs* per player? Per-season stats? Trophies? International caps? Career goals/assists totals? Transfer values? Preferred foot? Height? Answer each with a YES / PARTIAL (x%) / NO.
7. **Red flags** — any field that looks like a placeholder, a scrape artifact, mojibake, or an obviously wrong value (e.g. rating 0, age 0, birth year 1900).

### 0.2 Build the feasibility matrix
Then emit `docs/MODE_FEASIBILITY.md`: a table with one row per game mode from Section 5 of this brief, and these columns:

| Mode | Required fields | Available? | Verdict | Degradation plan |
|---|---|---|---|---|

Verdict is exactly one of:
- **GO** — all required fields present at >90% coverage.
- **DEGRADE** — buildable with a reduced ruleset (state precisely which rules are cut, e.g. "Grid can use club × nation × position categories but not trophy categories").
- **DEFER** — not buildable; needs data we don't have. List the exact fields needed so the data can be extended later.

### 0.3 Propose a derived-data layer
Most modes need facts the raw DB won't have directly. Specify (and later build) a **precompute pipeline** that runs at *build time*, not runtime, and ships its output as compact assets:

- `club_alumni_index` — clubId → Set(playerId) (needed by Grid, Connections, Bingo)
- `nation_index`, `position_index`, `decade_index`
- `category_cardinality` — for every puzzle category, how many valid answers exist (used to reject impossible/trivial puzzles)
- `answer_popularity` — a heuristic "obviousness" score per player (from rating, league prestige, career goals) used for the Grid rarity score
- `market_value_curve` — derived transfer value per player (see §6.4) if the DB lacks real values
- `puzzle_bank` — pre-generated, pre-validated puzzles (see §5.0)

### 0.4 Deliver the plan
Finally emit `docs/BUILD_PLAN.md`: phased milestones (see Section 10), with anything marked DEFER explicitly moved out of scope and recorded. **Stop and show me all three documents before writing app code.**

---

# SECTION 1 — PRODUCT DEFINITION

A single-player, **fully offline** Android game for football fans. Two halves to the product:

1. **The Puzzle Half** — short, sharp, repeatable knowledge challenges (grid, bingo, connections, quizzes, guess-the-player, goal chases). Sessions of 60 seconds to 5 minutes.
2. **The Career Half** — a lightweight, text-and-numbers management campaign across 15 seasons. Matches are **simulated, never played**. The joy is squad-building, transfers, tables, and stats — not gameplay.

Coins tie the two halves together: puzzles earn coins, career spends them.

### Design pillars
1. **Respect the fan's knowledge.** Hard means hard. No questions a casual could brute-force.
2. **Numbers are the art.** Tables, ratings, stat lines. Typography does the heavy lifting.
3. **Offline, instant, no account.** Zero network calls except the ad SDK. Cold start to playable in under 2 seconds.
4. **Quiet interface.** See Section 3. If it looks like a crypto app or a default AI template, it's wrong.

---

# SECTION 2 — TECH STACK & ARCHITECTURE

- **Flutter (stable), Dart 3**, Android only for v1 (min SDK 24, target latest).
- **State:** Riverpod (or Bloc — pick one and be consistent). No `setState` spaghetti outside leaf widgets.
- **Local DB:** ship the player database as a pre-built **SQLite** file in `assets/db/` (copied to app dir on first run) — or as compressed JSON if it's small (<8 MB). Query with `sqflite` + `drift`. Never parse a large JSON on the main isolate.
- **Save data:** separate writable SQLite DB (`save.db`) for careers, plus `shared_preferences` for settings/streaks. Career saves must survive app kill mid-season.
- **Heavy work off the UI thread:** season simulation, puzzle validation, and index loading run in an `Isolate` / `compute()`. The UI never blocks.
- **Architecture:** `lib/core` (theme, router, storage), `lib/data` (models, repos, DAOs), `lib/domain` (sim engine, puzzle engines, economy — pure Dart, no Flutter imports), `lib/features/<mode>` (UI per mode).
- **The simulation engine must be pure Dart and unit-testable.** Seeded RNG (`Random(seed)`) so any match can be reproduced for debugging.
- **Routing:** `go_router`. Deep, predictable back-stack.
- **Testing:** unit tests for the sim engine, economy, rating calculator, and every puzzle validator. Golden tests for the match-detail sheet and league table.

---

# SECTION 3 — VISUAL DESIGN SYSTEM (READ THIS TWICE)

### The brief in one line
**A well-made sports almanac, not a mobile game.** Think printed league table, broadsheet sports page, a clean stats site. Restrained, dense, confident.

### Hard bans
- ❌ Neon anything. No cyan/magenta/electric-purple.
- ❌ Gradients on buttons, glassmorphism, glow/bloom, drop shadows heavier than 2dp.
- ❌ Emoji as UI iconography.
- ❌ Bouncy, springy, overshooting animations. No confetti bursts on every tap.
- ❌ Generic "AI app" patterns: big pill gradient CTA, centered hero with a sparkle icon, purple-blue linear-gradient headers, rounded-32px floating cards on a gradient background.
- ❌ Stock illustration mascots.
- ❌ Sign-in screens. There is no account. First run asks for a manager name, nothing else.

### Palette (define once in `core/theme`, never hardcode a colour elsewhere)
| Token | Light | Dark | Use |
|---|---|---|---|
| `surface` | `#FAFAF8` | `#121311` | App background |
| `surfaceRaised` | `#FFFFFF` | `#1B1D1A` | Cards, sheets |
| `border` | `#E3E2DD` | `#2C2F2A` | 1px hairlines everywhere |
| `ink` | `#16181A` | `#EDEDE8` | Primary text |
| `inkMuted` | `#6B6F72` | `#9A9E98` | Labels, secondary |
| `accent` | `#1F6F4A` | `#3D9B6E` | Single accent — deep pitch green |
| `positive` | `#2E7D53` | — | Correct, win, gain |
| `negative` | `#A6402F` | — | Wrong, loss, injury |
| `warn` | `#B4802A` | — | Draw, fatigue, caution |

That is the **entire** palette. Rating badges use tonal steps of `accent`/`warn`/`negative` only. Dark mode is a first-class requirement, defaulting to system.

### Type
- One family, two weights: a clean grotesque (Inter, Manrope, or Söhne-like). Bundle it — no runtime font fetch.
- **Tabular figures (`fontFeatures: [FontFeature.tabularFigures()])` on every number in a table or rating.** Non-negotiable; misaligned digits kill the whole look.
- Scale: 28/22/17/15/13/11. Uppercase 11px with +0.08em tracking for section labels only.

### Layout
- 8px spacing grid. Corner radius 10px for cards, 8px for buttons, 999px only for small chips.
- Hairline dividers over shadows. Cards are defined by a 1px border, not elevation.
- Generous vertical rhythm; dense horizontally (stats are meant to be scanned).
- Motion: 150–200ms, `Curves.easeOutCubic`, opacity + 8px translate. Nothing else.
- One celebratory moment allowed per session end (a subtle rating count-up), never a particle effect.

### Club identity without infringement
Never ship crests, kits, or player photographs. Instead, generate a **monogram badge**: a 2-letter club abbreviation on a flat shape, tinted by a per-club colour pair stored in the DB. Players are represented by initials in a circle. This looks deliberate and is completely safe.

---

# SECTION 4 — LEGAL / IP GUARDRAILS (bake into the data layer)

- **Real player names, real club names, real league membership, and real career facts are used as factual data.** Keep them in a data file that can be swapped, and give every entity a `displayName` field so a name can be changed in one place.
- **No logos, crests, badges, kit designs, or photos.** Ever.
- **All competitions get generic names.** Use one naming scheme applied identically across every country:

| Real | In-game name |
|---|---|
| Domestic top division | *{Country} First Division* (e.g. "England First Division") |
| Champions League | **Continental Cup** |
| Europa League | **Continental Shield** |
| Conference League | **Continental Trophy** |
| FA Cup / Copa del Rey / DFB-Pokal / Coppa Italia | **National Cup** |
| Carabao / League Cup / Coupe de la Ligue | **League Cup** |
| Community Shield / Supercopa | **Season Shield** |
| World Cup | **World Championship** |
| Euros / Copa América / AFCON | **Continental Championship** |
| Club World Cup | **Global Club Championship** |

- Never use the strings FIFA, UEFA, EA, Premier League, La Liga, Bundesliga, Serie A, Ligue 1, Champions League, or any confederation name anywhere in the app, code, or store listing. Use "England First Division", "Spain First Division", etc.
- No real sponsor names, no stadium names that are trademarked brands (use "{City} Stadium").

---

# SECTION 5 — GAME MODES

Every mode below must specify, in code, a `ModeRequirements` object listing the DB fields it needs. At startup the app validates requirements and **hides any mode whose data is missing** rather than crashing or shipping a broken tile.

## 5.0 Shared puzzle infrastructure (build this before any individual mode)

**Puzzle generation is build-time, not runtime.** A generator script produces a validated bank of thousands of puzzles shipped as an asset. Runtime picks from the bank by seed + date.

Every generated puzzle must pass a **validator** before entering the bank:
- **Solvability:** at least `N` valid answers exist (N ≥ 3 for grid cells, ≥ 8 for bingo squares).
- **Non-triviality:** not *so* many answers that the cell is free. Reject cells with >400 valid answers unless flagged "easy".
- **Uniqueness of intersection:** row/column pairs must not be near-duplicates of each other.
- **Difficulty score:** computed from `log(validAnswerCount)` + mean obviousness of the top answers. Bucketed into Easy / Medium / Hard / Brutal.

Shared components:
- **Player search field** — fuzzy, accent-insensitive, nickname-aware ("Vini", "CR7" → correct player), debounce 120ms, ranked by rating + league prestige. Must feel instant over 20k+ rows (build an FTS5 index).
- **Timer widget** — thin linear bar, no ticking noise by default.
- **Result sheet** — score, time, coins earned, a shareable text summary (emoji grid, à la Wordle), "play again" / "next".
- **Daily vs Endless** — every puzzle mode has a *Daily* (one seeded puzzle per calendar day, streak-tracked) and an *Endless* (unlimited, random from bank) variant.

---

## 5.1 GRID — "The Nine"
3×3 grid; three row categories × three column categories. Nine guesses total, one per cell, each answer must satisfy both criteria. A player may only be used once across the whole grid.

**Category types** (only enable those the data supports — see feasibility matrix):
- Played for club X
- Nationality / continent
- Position
- Played in league X
- Rating ≥ 85 at some point / peak rating band
- Scored 100+ career goals
- Made 300+ career appearances
- Left-footed
- Played for 4+ clubs
- Debuted before/after a year
- Won a *National Cup* / *Continental Cup*
- Age band (under 21, over 34)

**Scoring — rarity system.** Lower is better. Each correct answer scores `round(100 × obviousness_share)` where obviousness_share is the precomputed popularity weight of that player among all valid answers for the cell. Perfect nine = "IMMACULATE". Show total rarity + per-cell rarity on the results screen. This is what gives the mode replay value — finding the obscure correct answer beats finding the famous one.

**Coins:** 1 coin per correct cell, +5 for 9/9, +10 if rarity total < 100.
**Ad hooks:** watch ad → +1 extra guess (max 2 per grid); watch ad → reveal one cell's category hint.

---

## 5.2 BINGO — "Full House"
5×5 board of 25 independent criteria (no intersections), free centre square. Player has 6 minutes (Daily) or untimed (Casual) to fill as many as possible. Each player usable once.

**Criteria pool:** won a *World Championship*; African/Asian/South American; played in 3+ different countries; a goalkeeper rated 85+; scored in a *Continental Cup* final; captained a club; over 35 years old; under 20; rating exactly in the 80s; 6'4"+ tall; one-club player; free transfer signing; played for two clubs in the same city.

**Scoring:** 2 pts per square; +10 per completed line (row/column/diagonal); +40 for full house. Streak bonus for consecutive correct fills.
**Coins:** points ÷ 5, rounded down.
**Ad hooks:** ad → +90 seconds (once); ad → swap one impossible square for a new criterion (max 2).

---

## 5.3 CONNECTIONS — "Four by Four"
16 player names in a shuffled grid. Four hidden groups of four. Four mistakes allowed.

**Group types must be non-obvious and overlapping by design** — that's the whole trick. Good examples:
- "All played for the same club"
- "All wore #9"
- "All were club captains"
- "All won the continental top-scorer award"
- "All Ballon-style award winners" (rename generically: *Player of the Year winners*)
- "All left-footed wingers"
- "All moved between two specific rival clubs"
- "All from the same national team squad"
- "All goalkeepers who have scored"

**Critical design rule:** the generator must deliberately place at least 2 "trap" players who plausibly fit two groups, then verify only one assignment yields a complete solution. Groups are colour-coded by difficulty in tonal steps of the accent (not rainbow colours): sand → sage → moss → deep green.

**Coins:** 8 for a solve, +4 for a flawless solve (0 mistakes).
**Ad hooks:** ad → remove one wrong name from consideration; ad → recover one mistake.

---

## 5.4 GUESS THE PLAYER — "Identikit"
A hidden player, revealed through a drip of clues. Six attempts. Each wrong guess (or "skip clue") reveals the next attribute:

1. Position + preferred foot
2. Nationality (continent first on Hard)
3. Current league
4. Age band
5. Overall rating band
6. Current club

**Wordle-style feedback on wrong guesses:** if you guess a player, show comparison arrows — same nationality ✓, same position ✓, rating higher ↑, age lower ↓, same league ✗. This turns it from a pure recall test into a deduction game and is the single best retention mechanic in this list. Implement it properly.

**Difficulty:** Easy = top-200 rated players only. Medium = top 1500. Hard = anyone with a professional record; clue order is scrambled and the nationality clue only gives continent.
**Coins:** 10 − (2 × guesses used), minimum 1.
**Ad hooks:** ad → one free extra clue without spending a guess.

---

## 5.5 GUESS THE XI — "Read the Teamsheet"
A full starting eleven shown on a pitch as shirt silhouettes with the number of letters in each surname. Fill in all 11 against a 4-minute clock. Sources: title-winning sides, cup-final lineups, or a generated "best XI of club X in year Y" from the DB.

3 hints available (reveal a letter). Partial credit. Tap a shirt to type.
**Coins:** 1 per correct player, +6 for all 11 with time left.
**Ad hooks:** ad → +2 hints; ad → +60 seconds.

---

## 5.6 BUILD THE XI — "Eleven Nations"
The daily lineup-builder. A formation is chosen (4-3-3, 4-4-2, 3-5-2, 3-4-3, 5-3-2). Eleven constraints are drawn — the classic being **eleven different nationalities, one per slot**, but rotate weekly through variants:

- **Eleven Nations** — one player from each of 11 countries.
- **Eleven Clubs** — one player from each of 11 clubs.
- **Alphabet XI** — each player's surname must start with a given letter.
- **Decade XI** — one player who debuted in each given year.
- **Budget XI** — free choice of players but total market value ≤ a cap (this is the best one; forces real trade-offs).

Constraint must be satisfied *and* the player must be able to play the slot's position. Validator guarantees at least one legal complete lineup exists for every formation offered; formations that can't be filled are greyed out.

**Scoring:** completion + the sum of the chosen XI's ratings (so there's a leaderboard-worthy "best possible XI" target). Show "your XI: 87.3 avg — the optimal XI was 91.1".
**Coins:** 6 on completion, +1 per rating point above 85 average.
**Ad hooks:** ad → reroll one constraint; ad → +10% budget in Budget XI.

---

## 5.7 GOAL CHASE — "The Ton" (Razzamatazz-style)
The addictive one. A target total (100 / 1,000 / 10,000 career goals) and a limited number of picks.

**Core loop:** you are shown a **roulette of 3 random players**, face-down, with only a hint visible (e.g. "Italian midfielder, 2000s"). Pick one. Their career goals are revealed and added to your running total. Repeat until your picks run out. Beat the target to win.

**Variants:**
- **Goals Chase** — reach 1,000 career goals in 12 picks.
- **Assist Chase** — same with assists.
- **Appearance Chase** — reach 5,000 appearances.
- **Survival** — an escalating target each round; one bad pick ends the run.
- **Duel** — Higher or Lower: two players shown, pick who scored more. Endless streak. (See 5.8.)

**Tension mechanics:** an on-screen "required average per remaining pick" counter updates live. Picking a defender when you need 90 goals in 1 pick is a visible disaster, and that's the fun.
**Coins:** 5 for a win, +1 per 200 goals of overshoot, 0 for a loss.
**Ad hooks:** ad → reroll the current trio; ad → one "second chance" per run; ad → double coins on a win.

---

## 5.8 HIGHER OR LOWER — "Over / Under"
Two players. One stat category (career goals, rating, appearances, age, market value, height). Pick higher. Endless streak; one mistake ends it. Personal best tracked. 10-second timer per round on Hard.
**Coins:** streak ÷ 3. **Ad hooks:** ad → continue a dead run once.

---

## 5.9 BUILD-A-PLAYER — "Frankenstein XI"
Draft a composite player by taking **one attribute from each of several real players**. You're shown 5 random players; pick whose *pace* you want. Then a new 5; pick whose *shooting*. Repeat for passing, dribbling, defending, physical (and for a GK variant: reflexes, handling, positioning, kicking).

Your Frankenstein's composite rating is computed with the same weighting the DB uses per position. Then it's graded: "Your build: 91 PAC / 74 SHO / … — overall 86, a right winger." Compare against the best possible build from the cards you were offered ("you left a 94 shooting on the table").

**Meta layer:** save your best builds to a personal "Lab" collection; a weekly seeded challenge gives everyone the same card pool so scores are comparable.
**Coins:** overall rating − 70, floored at 0.
**Ad hooks:** ad → one reroll of the current 5 cards; ad → a 6th card in one round.
**Data requirement:** per-attribute ratings (PAC/SHO/PAS/DRI/DEF/PHY or similar). If the DB only has an overall rating, this mode is **DEFER** — say so, don't fake attributes.

---

## 5.10 QUIZ — "The Interrogation"
Not a soft trivia mode. Four genuinely distinct difficulties, and the difficulty must come from *question construction*, not from a timer.

| Tier | Character | Example shape |
|---|---|---|
| **Casual** | Household names | "Which club does player X play for?" |
| **Committed** | Requires following the sport | "Which of these four players has the most career assists?" |
| **Hard** | Requires memory of specifics | "Which club did X play for *between* his spells at A and B?" / "Which of these four never played in Spain?" |
| **Brutal** | Requires deep, cross-referenced knowledge | "Which of these four is the only one to have played for clubs in four different countries *and* captained his national side?" / ordering questions: "Rank these four by career goals" |

**Question generation:** build a `QuestionTemplate` system — each template declares required fields, a difficulty tier, and a distractor strategy. **Distractor quality is what makes hard questions hard.** Rules:
- Wrong answers must be *plausible* — same position, same era, similar rating band, same league.
- Never let the correct answer be the only famous name among three obscure ones.
- For "which is the odd one out", the three non-answers must share a verifiable property.
- Cache which questions a user has seen; never repeat within 200 questions.

**Formats:** multiple choice, true/false, "odd one out", ranking (drag to order), "name any 5 of the 12" (open-ended, list-completion).
**Run structure:** 10 questions, lives system on Brutal (2 lives), streak multiplier.
**Coins:** 1/2/4/7 per correct answer by tier; ×2 for a perfect run.
**Ad hooks:** ad → 50/50 (remove two wrong answers); ad → skip a question; ad → revive.

---

## 5.11 CAREER — "THE LONG GAME"
The flagship. Full spec in Section 6.

---

## 5.12 TOURNAMENT LAB — "The Simulator"
Pure simulation sandbox, no management. Pick any competition and run it:

- **World Championship** (32 or 48 nations, groups + knockouts)
- **Continental Championship** (24 nations)
- **Continental Cup** (league-phase or 32-team group format)
- **Any domestic First Division** (full 38-game season)
- **Custom Cup** — hand-pick 8/16/32 clubs or nations from anywhere in the world and run a bracket. Real Madrid vs. a Japanese side vs. a Brazilian side: fine.

Output: full bracket/table, every result tappable to the match detail sheet, golden boot race, team of the tournament, and a simulation speed control (instant / round-by-round / dramatic). Let the user **re-run the same tournament with a new seed** and compare outcomes — cheap to build, very sticky.

**Coins:** small flat reward per completed tournament; this mode is mostly a toy and a career-mode test harness.

---

## 5.13 DAILY HUB
The home screen isn't a menu of tiles, it's a **fixture list of today's challenges**: Grid, Bingo, Connections, Identikit, Build-the-XI, one rotating mode. Completing all six = "Full Card" bonus (25 coins). Streak counter, calendar view of past days (replayable from the bank), and a "career continues" row pinned at the bottom if a save exists.

---

## 5.14 ADDITIONAL MODES WORTH BUILDING (ranked by value/effort)
1. **Career Path** — a player's clubs shown in order as anonymous timeline nodes (with years and appearance counts); name the player. Very cheap if career history exists; extremely popular format.
2. **Transfer Deadline** — a live-feed drill: a transfer is described ("£100m, 2017, to a French club") and you name the player or the fee. Great use of value data.
3. **Squad Draft Duel** — snake draft against an AI manager from a shared 60-player pool; the resulting XIs are compared by the sim engine over a simulated 5-match series. Directly reuses the career sim engine for a 4-minute mode.
4. **Ratings Auction** — you're given 500 "credits" and a rolling auction of 20 players; the AI bids against you; at the end your XI is rated. Teaches value and feeds Career.
5. **Stat Attack (Top Trumps)** — one card each, you pick the attribute to compete on, best of 9. Pure attribute data.
6. **Pyramid** — five tiers of clues about one theme (e.g. a nation's squad), easiest at the base, hardest at the apex.
7. **Blind XI** — the sim engine picks a formation and reveals each opponent's key stat; you pick a counter-lineup from a squad. Tactical, ties into Career.
8. **Retro Rewind** — "reconstruct the league table of season X" by dragging clubs into order. Needs historical standings; likely DEFER.

Build 1–3 for v1 if the data allows; note the rest in the backlog.

---

# SECTION 6 — CAREER MODE: "THE LONG GAME" (FULL SPEC)

## 6.1 Onboarding
1. **First app launch ever:** a single, quiet screen — "What should we call you, boss?" → manager name. Stored globally. No other onboarding, no tutorial wall, no permissions request.
2. **Starting a career** (from the menu, so multiple saves exist):
   - **Take a job** — choose any real club from any supported league. Its real squad becomes yours. Board expectations scale to club strength.
   - **Found a club** — enter a club name, short name (2–3 letters), choose two colours for the monogram badge, and choose which country's First Division to enter (you start in it directly, at the lowest reputation). You then have a budget to assemble a squad.
   - **Random XI** — you're dealt a randomly generated squad of 20. You may **swap 3 players** before confirming; each swap deals a new random player of the same position. Extra swaps cost coins or a rewarded ad (max 3 extra).
3. **Difficulty:** Relaxed / Standard / Unforgiving — affects budget, board patience, injury frequency, and AI transfer aggression.
4. 15 seasons maximum, then a **Career Summary** (trophies, records, best XI of the era, manager legacy score).

## 6.2 Squad rules
- **Squad size 20–24.** Exactly **11 starters**, 9–13 in bench/reserve. Minimum 18 registered or you can't start a match (auto-promote a youth player if short).
- Every player has: `position`, `overall`, per-position suitability, `age`, `stamina` (0–100), `morale` (0–100), `fitness/injury state`, `form` (rolling last-5 rating), `contract years`, `wage`, `value`.
- **Playing out of position** applies a rating penalty: adjacent position −3, unrelated −8, outfielder in goal −25.
- Formation picker with 6 shapes. Auto-pick-best-XI button (weights by position suitability × form × stamina).

## 6.3 The season structure
Each season includes, for the club's country:
- **First Division** — full double round-robin against the *real clubs* of that league plus (if founded) your club replacing the weakest.
- **National Cup** — single-elimination, all divisions, random draw.
- **League Cup** — single-elimination, top divisions only.
- **Continental Cup / Shield / Trophy** — qualification by previous-season league finish (top 4 → Cup, 5th–6th → Shield, 7th → Trophy). Group stage + knockouts.
- **Season Shield** — one-off match between league champion and National Cup winner.

Fixture congestion is real: 3 competitions at once means rotation matters, which is what makes stamina meaningful.

## 6.4 Transfers & economy
Two windows: **Pre-season** (large) and **Mid-season** (small, limited slots).

**Valuation formula** (use if DB lacks real values; tune until Haaland ≫ Morata and the curve feels right):

```
base        = 0.35 × 1.115^(overall - 60)           // £m, exponential in quality
ageFactor   = age<=21 ? 1.45 : age<=24 ? 1.35 : age<=27 ? 1.15
              : age<=30 ? 0.85 : age<=32 ? 0.55 : age<=34 ? 0.30 : 0.15
posFactor   = ST/W 1.25 | AM 1.15 | CM 1.0 | DM 0.95 | CB 0.90 | FB 0.85 | GK 0.75
formFactor  = 0.85 + (rollingRating - 6.5) × 0.10   // clamp 0.8–1.3
potFactor   = 1 + max(0, potential - overall) × 0.03
contract    = yearsLeft >= 3 ? 1.15 : yearsLeft == 2 ? 1.0 : yearsLeft == 1 ? 0.65 : 0.25

value = base × ageFactor × posFactor × formFactor × potFactor × contract
```

Sanity-check the output against reality during the audit and adjust constants until a 91-rated 24-year-old striker lands around £180–200m and a 79-rated 32-year-old forward lands around £6–10m.

**Buying:** selling clubs demand 100–160% of value depending on contract length, squad need, and your reputation. Negotiation is 2–3 rounds, not an infinite haggle. Big clubs refuse to sell to low-reputation managers outright.
**Selling:** you receive 75–110% of value; you get unsolicited bids for in-form players mid-season (accept/reject, with a morale consequence either way).
**Wages:** a weekly wage budget separate from transfer budget. Overspending triggers a board warning, then forced sales.
**Income:** league position prize money, cup runs, gate receipts (scale with reputation), player sales. Losing money for two seasons = sacked.

## 6.5 The simulation engine (the most important code in this app)

### Team strength
```
attack  = Σ(player.attackContribution × positionWeight × formMod × staminaMod) 
defence = Σ(player.defenceContribution × positionWeight × formMod × staminaMod)
```
Where `formMod = 0.9 + (form - 6.5)/10` and `staminaMod = 0.75 + 0.25 × (stamina/100)`.
Then normalise to a 0–100 scale so the numbers are legible to the player as "Attack 88 / Defence 81 / Overall 85".

### Expected goals
```
BASE_GOALS   = 1.35
homeAdv      = 1.18                     // away = 1/1.18
tacticMod    = f(attacking/balanced/defensive choice)
xG_home = BASE_GOALS × (attack_home / defence_away)^1.35 × homeAdv × tacticMod_home
xG_away = BASE_GOALS × (attack_away / defence_home)^1.35 / homeAdv × tacticMod_away
```
Clamp xG to [0.15, 4.5]. Draw actual goals from a **Poisson distribution** with that lambda. This is the correct model — it produces realistic scorelines, occasional giant-killings, and a believable goals-per-game distribution (~2.7). **Do not** use a naive "higher rating wins" comparison; it makes the whole mode boring within three seasons.

Validate: after building the engine, simulate 10,000 matches between an 85-rated and a 70-rated side. Expect roughly 72–80% wins for the stronger side, not 99%. Simulate a full 38-game season and check the champion lands on 80–95 points and the table spread looks real. Write this as a test.

### Goal & assist attribution
Each goal is assigned to a player by weighted random draw:

| Position | Goal weight | Assist weight |
|---|---|---|
| ST | 10.0 | 3.0 |
| W / LW / RW | 6.5 | 6.0 |
| AM | 5.5 | 7.0 |
| CM | 2.5 | 4.5 |
| DM | 0.8 | 1.8 |
| FB | 0.7 | 3.5 |
| CB | 1.0 (set pieces) | 0.5 |
| GK | 0.02 | 0.15 |

Multiply each weight by `(player.overall / 75)^2` and by `formMod`. Penalty takers get a boost. ~22% of goals get no assist. Own goals at ~2.5%.

### Player match ratings (the "tap the scoreline" payoff)
Start at **6.0**. Apply:

| Event | Modifier |
|---|---|
| Goal scored | GK +3.0, CB/FB +1.8, DM/CM +1.4, AM/W +1.2, ST +1.1 |
| Assist | +0.75 |
| Clean sheet (played 60+) | GK +1.1, CB/FB +0.85, DM +0.35, others +0.1 |
| Each goal conceded beyond the 1st | GK −0.30, CB/FB −0.18, DM −0.08 |
| Team won / drew / lost | +0.30 / 0.00 / −0.30 |
| Quality drift | `(overall − 75) / 22`, clamped ±0.6 |
| Out of position | −0.4 |
| Low stamina (<55) | −0.35 |
| Yellow card (~9% chance/player) | −0.25 |
| Red card (~0.8%) | −1.3 |
| Penalty missed | −1.0 |
| Substitute (played <45') | all modifiers ×0.6, base 6.2 |
| Random noise | Gaussian σ = 0.32 |

Clamp to **[3.5, 10.0]**, round to 1 decimal. **Man of the Match** = highest rating, must be ≥ 7.3; on a loss, MOTM goes to the opposition. A rating of 10.0 should be rare — roughly 1 in 300 performances.

Feed ratings back into `form` (rolling mean of last 5) and `morale` (+3 for ≥7.5, −4 for ≤5.5, plus result effect).

### Events between matches
After each fixture, roll for:
- **Injury** — base 4% per starter per match, scaled by stamina (below 40 stamina → 11%) and age (over 32 → ×1.4). Severity: knock (1 match) 55% / minor (2–4) 30% / moderate (5–10) 12% / serious (12–30) 3%.
- **Fatigue** — stamina drops 18–28 per 90 minutes, recovers 12–18 per rest day. A player under 45 stamina who starts gets a big rating penalty and double injury risk. This is the core rotation puzzle.
- **Personal leave** — ~1.5% per player per month (family event, international duty, personal reasons). Refusing costs morale.
- **Unhappiness** — a player with low morale and low minutes may request a transfer or refuse to sit on the bench.
- **Hot streak / slump** — a player can enter a 3–6 match form state with modified goal weights.
- **Suspension** — 5 yellows = 1 match ban; red = 1–3 matches.

Surface these as a short, plain **inbox** on the hub — one line per item, no popups interrupting the flow.

## 6.6 Match day UX (get this exactly right)
1. **Pre-match:** opponent name, their form (last 5 as W/D/L pills), their overall/attack/defence, your XI with warnings (tired ✱, injured ✕, out of position ⚠), tactic selector (Attacking / Balanced / Defensive / Counter / Park the Bus — each a small modifier to xG for and against).
2. **Simulate.** Three speeds: Instant / Timeline (goals appear one by one over ~6 seconds) / Full. No fake 2D pitch.
3. **Result card** — exactly like a search-engine score card:
   ```
   ┌───────────────────────────────────────┐
   │  NEWCASTLE UNITED      2 — 1   ARSENAL│
   │  Isak 34'                 Saka 71'    │
   │  Gordon 62'                           │
   │  England First Division · Matchday 14 │
   └───────────────────────────────────────┘
   ```
4. **Tap the scoreline → Match Detail sheet** with tabs:
   - **Lineups** — both XIs on a pitch diagram, each shirt showing the rating badge, goal/assist/card icons, subs listed below with minute of entry.
   - **Stats** — possession, shots, shots on target, xG, corners, fouls, cards (all derived consistently from the sim, never random-and-contradictory).
   - **Ratings** — sortable list, both teams, MOTM highlighted.
   - **Timeline** — minute-by-minute event list.
5. Every past result in every table and bracket is tappable to the same sheet. Persist match detail compactly (store the seed + events, not full objects).

## 6.7 Tables, brackets, and stats screens
- **League table** — Pos, Club, P, W, D, L, GF, GA, GD, Pts, Form (last 5). Your club row subtly highlighted. Correct tiebreakers (points → GD → GF → head-to-head). Zone markers as left-edge colour bars (continental spots, relegation), never full-row fills.
- **Cup brackets** — horizontally scrollable, every tie tappable.
- **Stats hub, per competition *and* aggregated** (this is the FIFA-style depth requested):
  - Player: appearances, starts, minutes, goals, assists, G+A, goals per 90, clean sheets, yellow/red cards, average rating, MOTM awards, penalties scored/missed.
  - Team: W/D/L, goals for/against, clean sheets, biggest win, longest unbeaten run, points per game, average squad rating, average age.
  - Leaderboards: top scorers, top assists, best average rating (min 10 appearances), most clean sheets — for your league, not just your club.
  - **Season review** at year end: Team of the Season, Player of the Season, your club's record book updates, board verdict, trophy cabinet.
- **Hall of records across the whole 15-season career** — most goals ever, best season, every trophy won, every manager-of-the-month.

## 6.8 Board, objectives, and the sack
Each season the board sets: a league finish target, a cup expectation, and a financial expectation. A rolling confidence meter (0–100) moves with results, competition progress, and finances. Below 15 for 5 matches → sacked → offer of a job at a smaller club or career end. Exceeding expectations raises reputation, which unlocks bigger jobs and better transfer targets.

---

# SECTION 7 — ECONOMY, COINS & ADS

## 7.1 Two currencies, kept strictly separate
- **Coins** — the meta currency, earned in puzzle modes and via ads. Used for: hints, extra guesses, rerolls, continues, cosmetic badge styles, extra career save slots, unlocking Brutal quiz packs, and buying **Transfer Credits**.
- **Club Funds (£)** — career-internal only, earned in-game. **Never purchasable directly with coins**, or the career mode is dead on arrival. Coins can only buy *Transfer Credits*, a capped, seasonal one-off (see below).

## 7.2 Coin faucets and sinks
| Faucet | Amount |
|---|---|
| Any daily puzzle completed | 5–15 |
| Full Card (all six dailies) | +25 |
| Streak milestones (3/7/14/30 days) | 15 / 40 / 90 / 250 |
| Career match win / cup win / title | 3 / 25 / 120 |
| Rewarded ad | 20 |
| First-run gift | 150 |

| Sink | Cost |
|---|---|
| Grid extra guess | 30 |
| Quiz 50/50 | 20 |
| Identikit extra clue | 25 |
| Goal Chase reroll | 35 |
| Career: extra random-XI swap | 60 |
| Career: **Transfer Credit** (+8% budget, max 2 per window) | 250 |
| Career: rush an injury recovery by 1 match (max 1/player/season) | 200 |
| Extra career save slot | 400 |
| Badge/theme cosmetics | 300–800 |

Tune so a daily-active player earns ~60–90 coins/day and a moderate spender needs ads for roughly a third of their consumption. Never gate a *mode* behind coins — only assistance.

## 7.3 Ads (Google AdMob, added in Phase 6 behind a feature flag)
- **Rewarded video only** for anything that affects gameplay. Every ad is opt-in, every ad button states the exact reward up front.
- **Interstitial:** at most one per 4 minutes of play, and only at natural boundaries (after a result screen, between career matches — never mid-season-simulation, never before a daily puzzle). Hard frequency cap: 1 per 180 seconds, max 12/day.
- **Banner:** only on the hub/menu and squad-list screens. Never on a puzzle board, never on the match detail sheet.
- **Architecture:** wrap everything in an `AdService` interface with a `NoOpAdService` for development and a `RemoteConfigless FeatureFlags` class. The game must be fully playable and enjoyable with ads disabled — build and test it that way first.
- Include a one-time IAP hook (`remove_ads`) stubbed but not wired.

---

# SECTION 8 — PERSISTENCE, PERFORMANCE & QUALITY BARS

- Cold start → hub in **< 2s** on a mid-range device (Snapdragon 6-series).
- A full 38-game season with three cups simulates in **< 3s** in an isolate, with a progress indicator.
- Player search returns results in **< 80ms** over the full DB.
- Memory: never hold the whole player table in RAM; page and index.
- **Autosave** after every match, transfer, and puzzle completion. Crash mid-season must lose at most one action.
- Save versioning with a migration path from day one (`save_schema_version`).
- Handle: app killed during simulation, device rotation, low-memory reclaim, system dark-mode toggle mid-session.
- Accessibility: full text scaling support up to 200%, semantic labels on every interactive element, no colour-only information (pair every colour cue with a glyph or letter), 48dp minimum touch targets.
- Localisation-ready: no hardcoded strings in widgets; all text through an `AppStrings` layer even if English-only at launch.

---

# SECTION 9 — WHAT "POLISHED" MEANS HERE (checklist to self-review against)

- [ ] Every number in every table uses tabular figures and is right-aligned.
- [ ] No screen has more than one accent-coloured element.
- [ ] Empty states are written, not blank ("No transfers yet this window.").
- [ ] Loading states are skeletons matching final layout, not spinners.
- [ ] Every destructive action (abandon career, reset streak) has a confirm.
- [ ] Back button behaviour is correct on every screen, including mid-puzzle (confirm before quitting a timed run).
- [ ] Haptics: light impact on correct, medium on wrong, selection click on tap. Nothing more.
- [ ] Sound is off by default; if added, one subtle UI click set and nothing else.
- [ ] The app looks identical and correct in light and dark mode — screenshot both for every screen.
- [ ] Nothing on screen says "AI", "powered by", "generated", or uses a sparkle icon.

---

# SECTION 10 — BUILD PLAN (phases; ship each as a working build)

**Phase 0 — Audit.** Section 0 deliverables. *Stop and review.*
**Phase 1 — Foundation.** Theme, tokens, typography, routing, DB ingestion + FTS index, player search widget, manager-name onboarding, hub shell. Build a `/debug` screen that dumps DB stats.
**Phase 2 — Puzzle engine + 3 modes.** Shared puzzle infra, generator + validator, puzzle bank. Ship Grid, Identikit, Higher-or-Lower end to end with results, streaks, and coins.
**Phase 3 — Remaining puzzle modes.** Bingo, Connections, Guess-the-XI, Build-the-XI, Goal Chase, Quiz, Build-a-Player (if data allows). Daily Hub with Full Card.
**Phase 4 — Simulation engine.** Pure Dart, fully unit-tested, with the 10,000-match validation suite. Tournament Lab built on top as the engine's test harness and first shippable surface.
**Phase 5 — Career mode.** Onboarding paths, squad management, fixtures, match day, match detail sheet, tables, brackets, stats hub, injuries/fatigue/morale, transfers, board, season rollover, 15-season arc, save/load.
**Phase 6 — Economy & ads.** Coin ledger, sinks/faucets, AdMob behind flags, rewarded placements.
**Phase 7 — Polish.** Section 9 checklist, performance pass, accessibility pass, empty/error states, app icon, store assets.

After each phase: a short `docs/PHASE_N_NOTES.md` listing what shipped, what changed from this brief and why, and any new DEFER items.

---

# SECTION 11 — RULES OF ENGAGEMENT FOR YOU (the agent)

1. **Never invent football data.** If a fact isn't in the database, the feature that needs it is DEFER. Do not hardcode player careers, trophies, or stats from memory — they will be wrong and the whole product's credibility rests on the data being right.
2. **Ask before assuming.** If a mode's rules are ambiguous given the actual data, write the question into `docs/OPEN_QUESTIONS.md` and pick the conservative option meanwhile.
3. **Pure logic stays out of widgets.** Sim engine, valuation, rating calculation, and puzzle validation live in `lib/domain` with no Flutter imports and full test coverage.
4. **Seeded randomness everywhere.** Every random outcome derives from a stored seed so bugs are reproducible and daily puzzles are identical across devices.
5. **Balance is a deliverable, not an afterthought.** Ship the tuning constants (xG base, injury rates, valuation coefficients, coin amounts) in a single `lib/domain/balance.dart` file with comments, so they can be tuned without hunting through code.
6. **Build vertically.** One mode fully finished — including results screen, coins, empty states, and dark mode — beats six half-built ones.


Start with section 0
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-09-18T05:20:32+05:00.
</ADDITIONAL_METADATA>
<USER_SETTINGS_CHANGE>
The user changed setting `Model Selection` from None to Claude Opus 4.6 (Thinking). No need to comment on this change if the user doesn't ask about it. If reporting what model you are, please use a human readable name instead of the exact string.
</USER_SETTINGS_CHANGE>