# OPEN QUESTIONS

*Raised during data audit — Section 0*
*Conservative defaults noted; override with your preference.*

---

## Q1. Player ID collision: ID `20801`

**Issue:** Player ID `20801` maps to both **"Cristiano Ronaldo"** and **"Harry Kane"** in the database.

**Context:** In the original EA FIFA database, ID `20801` is Cristiano Ronaldo. Harry Kane's correct FIFA ID is `202126`. This appears to be a data entry error in the retro or historical data.

**Conservative default:** Keep Ronaldo as `20801`, assign Harry Kane a corrected ID (either `202126` if it doesn't conflict, or a new synthetic ID `9100001`).

**Decision needed:** Confirm this fix, or provide the correct Harry Kane ID.

---

## Q2. Name variants (198 players)

**Issue:** 198 Player IDs map to multiple distinct name strings across seasons. Examples:
- `5471` → "F. Lampard" / "Frank Lampard"
- `7826` → "R. van Persie" / "Robin van Persie"
- `13743` → "S. Gerrard" / "Steven Gerrard"

This is because modern EA FIFA data uses abbreviated names ("M. Salah") while retro data uses full names ("Mohamed Salah").

**Conservative default:** Use the **most complete/longest name** as the canonical `displayName`. Keep all variants in a search alias table so "F. Lampard" and "Lampard" both find the same player.

---

## Q3. Mid-season transfer duplicates (76 entries)

**Issue:** 76 rows have the same Player ID + Season + Mode but different teams (e.g., Sánchez appears at both Arsenal and Man Utd in 2018).

**Conservative default:** These are **legitimate** — they represent players who moved mid-season. Both entries are kept. For puzzle modes, this means a player can correctly answer "played for Arsenal" AND "played for Man Utd" in the same season. For Career mode, the latest-season entry for a club determines the starting squad.

---

## Q4. Which data snapshot is "current"?

**Issue:** The database has multiple seasons. Career mode needs a "current" roster for each club.

**Options:**
- (a) Use the **latest available season per club** (FC 27 for clubs that have it, FC 26 for others, etc.)
- (b) Use only **one consistent season** (e.g., 2026) for all clubs
- (c) Let the player **choose the season** when starting a career

**Conservative default:** Option (a) — use the latest season per club, with FC 25/26/27 data prioritized over historical PL/Euro data. This gives the most up-to-date squads.

---

## Q5. Nations Cup players have no age

**Issue:** All 8,731 Nations Cup players have `null` age. This affects age-based puzzle categories and the Identikit age clue.

**Options:**
- (a) Exclude NC players from age-based puzzles entirely
- (b) Attempt to infer ages from tournament year + player name cross-reference with club data
- (c) Accept missing ages and skip the age clue in Identikit when unavailable

**Conservative default:** Option (a) — exclude from age-based puzzles. Option (b) would be better but requires the precompute pipeline to do name-matching with imperfect results.

---

## Q6. Career mode squad size trimming

**Issue:** DB squads average ~30 players, but Career mode specifies 20–24.

**Conservative default:** When initializing a Career save, trim the squad to 24 by:
1. Keep all players rated 75+ (or the top 20 by OVR)
2. Ensure positional balance: at least 2 GK, 4 DEF, 4 MID, 2 FWD
3. Trim lowest-rated surplus players
4. Trimmed players enter a "free agent" pool available in the transfer market

---

## Q7. Competition names for the game

**Issue:** The database uses "Premier League", "European League", and "Nations Cup" as mode names. The brief requires generic competition names (e.g., "England First Division").

**Conservative default:** Map at the display layer:
- "Premier League" → "England First Division"
- "European League" → Keep per-club country: "Spain First Division" (for Barcelona), "Germany First Division" (for Bayern), etc.
- "Nations Cup" → "World Championship"

**Complication:** The European League sheet contains clubs from **multiple countries** (Spain, Germany, France, Italy, England, Portugal, Netherlands, Turkey). Each club needs a country mapping for the display name. This mapping must be hand-authored or derived from the team code.

---

## Q8. EA FC 25/26/27 as separate modes or merged?

**Issue:** The database has EA FC 25, 26, and 27 as separate sheets/modes alongside the historical Premier League and European League data. These contain overlapping clubs with different rosters.

**Conservative default:** Treat FC 25/26/27 as the **latest season data** for those clubs, merging them into the main club history. For Career mode, use FC 27 (2027) as "current season", FC 26 (2026) as "last season", etc. For puzzle modes, include all players from all modes in the unified pool.
