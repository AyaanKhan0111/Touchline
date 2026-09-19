# MODE FEASIBILITY MATRIX

*Based on data audit of `Football_Database_Expanded.xlsx`*
*Generated from Section 0.2 of the build brief*

---

## Database Capabilities Summary

Before the per-mode matrix, here is what the database **does and does not** contain:

### Available (high coverage)
- ✅ Player names, overall ratings (100%)
- ✅ 6 attribute stats: PAC/SHO/PAS/DRI/DEF/PHY (100%)
- ✅ Primary position, all eligible positions (100%)
- ✅ Club/team membership per season (100%)
- ✅ Mode/league context (100%)
- ✅ Is Goalkeeper flag (100%)
- ✅ Jersey colours per team (~95%)
- ✅ Squad catalog with star player, position breakdown (849 squads)

### Available (partial)
- ⚠️ Age (63.7% — missing for all Nations Cup players)
- ⚠️ Shirt Number (93.1%)
- ⚠️ Multi-club history (inferable for ~9.2% of players from cross-season data)
- ⚠️ Nationality (inferable only for Nations Cup players; club-mode players have NO nationality)
- ⚠️ Squad Rating Weights (62.4%)

### Missing entirely
- ❌ Career goals, assists, appearances
- ❌ Transfer values / market value
- ❌ Trophies / titles / awards
- ❌ Preferred foot
- ❌ Height / weight
- ❌ International caps
- ❌ Previous clubs (explicit transfer history)
- ❌ Captain status
- ❌ Penalty taker / set piece data
- ❌ Jersey number history (only current)

---

## Feasibility Matrix (Post-Enrichment)

| # | Mode | Required Fields | Enriched Status | Verdict | Upgrade / Implementation Plan |
|---|---|---|---|---|---|
| 5.0 | **Shared Puzzle Infra** | Player name, team, position, OVR, 6 attrs | ✅ All present at 100% | **GO** | Fully functional with SQLite FTS5 search. |
| 5.1 | **Grid — "The Nine"** | Club history, nationality, position, league, rating, age, career goals, foot | ✅ 98.3% nationality, 73.4% foot, 26.4% career goals | **IMPROVED** | Unlocks nationality, left-foot, right-foot, rating bands, age bands, and 50+ career goals categories. Highly diverse puzzle grid. |
| 5.2 | **Bingo — "Full House"** | Height, foot, nationality, rating, age, position | ✅ 73.4% height & foot, 98.3% nationality | **IMPROVED** | Restores "6'4+ tall", "left-footed", "South American", "African", "Over 35", etc. Full 25-criteria pool available without artificial padding. |
| 5.3 | **Connections — "Four by Four"** | Club history, shirt #, nationality, foot, rating | ✅ 98.3% nationality, 73.4% foot, 93.1% shirt # | **IMPROVED** | Unlocks rich grouping: "Same nationality", "All left-footed", "Wore #7/#9/#10", "All played for club X", "All rating 90+". |
| 5.4 | **Guess the Player — "Identikit"** | Position, foot, nationality, league, age, OVR, club | ✅ 98.3% nationality, 73.4% foot, 100% club/pos/OVR | **IMPROVED** | Clue sequence fully restored: 1) Position, 2) Nationality, 3) Preferred foot, 4) Age/League, 5) Rating, 6) Club. |
| 5.5 | **Guess the XI — "Read the Teamsheet"** | Full squad rosters | ✅ 849 squads available | **DEGRADE** | Synthesize "Best XI" per squad based on position fit + OVR rating. Framed as "Best XI of [Club] [Year]". |
| 5.6 | **Build the XI — "Eleven Nations"** | Nationality per player, formation positions, OVR | ✅ 98.3% nationality | **IMPROVED** | "Eleven Nations" variant works across all club and national teams. "Eleven Clubs", "Decade XI", "Budget XI" all functional. |
| 5.7 | **Goal Chase — "The Ton"** | Career goals, assists, appearances | ✅ 6,498 players with career totals | **GO** | **UNLOCKED**: Career goals, assists, and appearances from Transfermarkt now enable full gameplay! |
| 5.8 | **Higher or Lower — "Over / Under"** | Career goals, appearances, age, OVR, height, market value | ✅ Career stats, height, OVR, market value present | **IMPROVED** | Unlocks career goals, appearances, height (cm), market value (£M), and 6 core stats. Vastly superior variety. |
| 5.9 | **Build-a-Player — "Frankenstein XI"** | Per-attribute ratings (PAC/SHO/PAS/DRI/DEF/PHY) | ✅ All 6 stats present at 100% | **GO** | Pristine coverage. |
| 5.10 | **Quiz — "The Interrogation"** | Club history, nationality, career stats, multi-club, age | ✅ Career goals, transfers, nationality available | **IMPROVED** | Career milestone questions ("Who scored more career goals?"), nationality questions, transfer questions now viable. |
| 5.11 | **Career — "The Long Game"** | OVR, 6 attrs, position, club, age, potential | ✅ 61.6% potential, 63.7% market value | **GO** | Youth scouting unlocked via FC24 potential attribute. Derived market valuation calibrated. |
| 5.12 | **Tournament Lab — "The Simulator"** | Squad rosters, OVR, team strengths | ✅ 849 squads with full rosters | **GO** | Sim engine with club & national teams. |
| 5.13 | **Daily Hub** | Depends on constituent modes | ✅ 10 GO, 8 IMPROVED | **GO** | Full daily card with Grid, Identikit, Goal Chase, H/L, and Bingo. |
| 5.14.1 | **Career Path** | Previous clubs per player | ⚠️ Multi-club cross-season | **DEGRADE** | Usable for players with 2+ club appearances across seasons. |
| 5.14.2 | **Transfer Deadline** | Transfer history, fees, clubs | ✅ Transfermarkt transfer records available | **GO** | **UNLOCKED**: Historical transfer database linked to players. |
| 5.14.3 | **Squad Draft Duel** | OVR, position, 6 attrs, sim engine | ✅ All present | **GO** | Uses career sim engine directly. |
| 5.14.4 | **Ratings Auction** | OVR, position | ✅ All present | **GO** | Pristine coverage. |
| 5.14.5 | **Stat Attack (Top Trumps)** | 6 attribute stats, OVR, position | ✅ All present | **GO** | Pristine coverage. |
| 5.14.6 | **Pyramid** | Nationality, club, career facts | ✅ Enriched attributes | **IMPROVED** | Richer clue bank with nationality, foot, career goals. |
| 5.14.7 | **Blind XI** | Sim engine, squad data | ✅ All present | **GO** | Pristine coverage. |
| 5.14.8 | **Retro Rewind** | Historical league standings | ❌ No league standings data | **DEFER** | Requires historical league final tables. Deferred to post-launch. |

---

## Post-Enrichment Summary

| Verdict | Count | Modes |
|---|---|---|
| **GO** | 10 | Shared Infra, Goal Chase, Transfer Deadline, Build-a-Player, Career, Tournament Lab, Daily Hub, Squad Draft Duel, Ratings Auction, Stat Attack, Blind XI |
| **IMPROVED / DEGRADE** | 8 | Grid, Bingo, Connections, Identikit, Guess the XI, Build the XI, Higher or Lower, Quiz, Career Path, Pyramid |
| **DEFER** | 1 | Retro Rewind only (needs historical league table standings) |

> [!IMPORTANT]
> **Data Integrity Bug Fixed**: Player ID `20801` is now exclusively Cristiano Ronaldo. Harry Kane has been reassigned to his official FIFA ID `202126`.
> Name unification completed (e.g. Frank Lampard canonical across all appearances).

