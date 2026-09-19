"""
Data Enrichment Pipeline for Touchline Football Game.
Merges supplementary data from EA FC24 and Transfermarkt into the main database.

Steps:
  1. Fix data integrity (ID collisions, name unification)
  2. Merge FC24 attributes (nationality, foot, height, weight, potential)
  3. Merge Transfermarkt career stats (goals, assists, appearances)
  4. Hand-author club → country mapping
  5. Export enriched database as SQLite
"""
import pandas as pd
import numpy as np
import sqlite3
import os
import sys
import re
import unicodedata
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR = r"c:\Users\Ayaan\Downloads\Video\Football"
DB_PATH = os.path.join(BASE_DIR, "Football_Database_Expanded.xlsx")
FC24_PATH = os.path.join(BASE_DIR, "data_sources", "fc24", "male_players.csv")
TM_PLAYERS_PATH = os.path.join(BASE_DIR, "data_sources", "players.csv")
TM_APP_PATH = os.path.join(BASE_DIR, "data_sources", "appearances.csv")
TM_TRANSFERS_PATH = os.path.join(BASE_DIR, "data_sources", "transfers.csv")
TM_VALUATIONS_PATH = os.path.join(BASE_DIR, "data_sources", "player_valuations.csv")
OUT_DIR = os.path.join(BASE_DIR, "assets", "db")
os.makedirs(OUT_DIR, exist_ok=True)

# ═══════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════

def normalize_name(name):
    """Normalize a player name for fuzzy matching."""
    if not isinstance(name, str):
        return ""
    # Remove accents
    nfkd = unicodedata.normalize('NFKD', name)
    ascii_name = ''.join(c for c in nfkd if not unicodedata.combining(c))
    # Lowercase
    ascii_name = ascii_name.lower().strip()
    # Remove common prefixes/suffixes
    ascii_name = re.sub(r'\b(jr\.?|sr\.?|ii|iii|iv)\b', '', ascii_name)
    # Remove punctuation except spaces and hyphens
    ascii_name = re.sub(r"[^a-z0-9\s\-]", "", ascii_name)
    # Collapse whitespace
    ascii_name = re.sub(r'\s+', ' ', ascii_name).strip()
    return ascii_name

def expand_abbreviated_name(short, full_options):
    """Try to match 'F. Lampard' to 'Frank Lampard' from a list of options."""
    if not short or '.' not in short:
        return short
    parts = short.split()
    if len(parts) < 2:
        return short
    # Get the surname (last part)
    surname = parts[-1].lower()
    for full in full_options:
        full_parts = full.split()
        if len(full_parts) >= 2 and full_parts[-1].lower() == surname:
            if len(full) > len(short):
                return full
    return short

# ═══════════════════════════════════════════════════════════════════
# CLUB → COUNTRY MAPPING (hand-authored, real)
# ═══════════════════════════════════════════════════════════════════

CLUB_COUNTRY_MAP = {
    # England
    'Manchester United': 'England', 'Chelsea': 'England', 'Manchester City': 'England',
    'Arsenal': 'England', 'Tottenham Hotspur': 'England', 'Liverpool': 'England',
    'Everton': 'England', 'Newcastle United': 'England', 'West Ham United': 'England',
    'Aston Villa': 'England', 'Leicester City': 'England', 'Southampton': 'England',
    'Crystal Palace': 'England', 'Burnley': 'England', 'AFC Bournemouth': 'England',
    'Wolverhampton Wanderers': 'England', 'Brighton & Hove Albion': 'England',
    'Fulham': 'England', 'Brentford': 'England', 'Nottingham Forest': 'England',
    'Leeds United': 'England', 'West Bromwich Albion': 'England',
    'Stoke City': 'England', 'Swansea City': 'England',  # technically Wales, but PL
    'Hull City': 'England', 'Sunderland': 'England',
    'Queens Park Rangers': 'England', 'Norwich City': 'England',
    'Watford': 'England', 'Middlesbrough': 'England',
    'Huddersfield Town': 'England', 'Cardiff City': 'England',  # Wales, but PL
    'Sheffield United': 'England', 'Luton Town': 'England',
    'Ipswich Town': 'England', 'Blackburn Rovers 1994-95': 'England',
    'Tottenham': 'England',  # alternate name in Euro sheet

    # Spain
    'Barcelona': 'Spain', 'Real Madrid': 'Spain', 'Atlético Madrid': 'Spain',
    'Valencia': 'Spain', 'Sevilla': 'Spain',
    'Deportivo La Coruña': 'Spain',

    # Germany
    'Bayern Munich': 'Germany', 'Borussia Dortmund': 'Germany',
    'Bayer Leverkusen': 'Germany', 'RB Leipzig': 'Germany',

    # France
    'Paris Saint-Germain': 'France', 'Monaco': 'France', 'Marseille': 'France',

    # Italy
    'Juventus': 'Italy', 'AC Milan': 'Italy', 'Inter': 'Italy', 'Inter Milan': 'Italy',
    'Napoli': 'Italy', 'Lazio': 'Italy', 'AS Roma': 'Italy',

    # Portugal
    'Benfica': 'Portugal', 'Porto': 'Portugal', 'Sporting CP': 'Portugal',

    # Netherlands
    'Ajax': 'Netherlands', 'PSV Eindhoven': 'Netherlands',

    # Scotland
    'Celtic': 'Scotland',

    # Turkey
    'Galatasaray': 'Turkey',
}

# ═══════════════════════════════════════════════════════════════════
# STEP 1: Load & fix data integrity
# ═══════════════════════════════════════════════════════════════════

print("STEP 1: Loading and fixing data integrity...")
master = pd.read_excel(DB_PATH, sheet_name='All Players Master')
teams_cat = pd.read_excel(DB_PATH, sheet_name='Teams & Squads Catalog')
print(f"  Loaded: {len(master)} player rows, {len(teams_cat)} team entries")

# Fix 1a: Harry Kane ID collision
# ID 20801 is Cristiano Ronaldo's official FIFA ID
# Harry Kane's correct FIFA ID is 202126
kane_mask = (master['Player ID'] == 20801) & (master['Player Name'].str.contains('Kane', case=False, na=False))
kane_count = kane_mask.sum()
if kane_count > 0:
    master.loc[kane_mask, 'Player ID'] = 202126
    print(f"  Fixed: Reassigned {kane_count} Harry Kane rows from ID 20801 → 202126")

# Also check if any rows with ID 20801 are actually Harry Kane by team
kane_mask2 = (master['Player ID'] == 20801) & (master['Player Name'].str.contains('Harry Kane', case=False, na=False))
if kane_mask2.sum() > 0:
    master.loc[kane_mask2, 'Player ID'] = 202126
    print(f"  Fixed: Additional {kane_mask2.sum()} Harry Kane rows reassigned")

# Fix 1b: Unify player names to fullest version
print("  Unifying player names to full versions...")
name_groups = master.groupby('Player ID')['Player Name'].apply(list).to_dict()
canonical_names = {}
for pid, names in name_groups.items():
    unique_names = list(set(names))
    if len(unique_names) == 1:
        canonical_names[pid] = unique_names[0]
    else:
        # Pick the longest name (most complete)
        longest = max(unique_names, key=len)
        canonical_names[pid] = longest

# Apply canonical names
master['Player Name'] = master['Player ID'].map(canonical_names)
unified_count = sum(1 for pid, names in name_groups.items() if len(set(names)) > 1)
print(f"  Unified {unified_count} players with name variants")

# ═══════════════════════════════════════════════════════════════════
# STEP 2: Merge FC24 attributes
# ═══════════════════════════════════════════════════════════════════

print("\nSTEP 2: Merging EA FC24 attributes...")
fc24 = pd.read_csv(FC24_PATH, low_memory=False)

# Get latest version per player
fc24_latest = fc24.sort_values('fifa_update', ascending=False).drop_duplicates('player_id')
print(f"  FC24 unique players: {len(fc24_latest)}")

# Prepare merge columns
fc24_merge = fc24_latest[['player_id', 'long_name', 'nationality_name', 'preferred_foot',
                           'height_cm', 'weight_kg', 'potential', 'weak_foot',
                           'skill_moves', 'work_rate', 'international_reputation',
                           'value_eur', 'wage_eur', 'dob']].copy()
fc24_merge = fc24_merge.rename(columns={'player_id': 'Player ID'})

# Convert our Player IDs to int where possible for matching
def safe_int(x):
    try:
        return int(x)
    except (ValueError, TypeError):
        return x

master['Player ID_orig'] = master['Player ID']
master['_merge_id'] = master['Player ID'].apply(safe_int)

# Get unique player IDs from our DB (numeric only)
numeric_mask = master['_merge_id'].apply(lambda x: isinstance(x, int))
numeric_players = master[numeric_mask][['_merge_id', 'Player Name']].drop_duplicates('_merge_id')
numeric_players = numeric_players.rename(columns={'_merge_id': 'Player ID'})

# Merge
merged_fc24 = numeric_players.merge(fc24_merge, on='Player ID', how='left')
matched = merged_fc24['nationality_name'].notna().sum()
total = len(merged_fc24)
print(f"  Matched: {matched}/{total} ({100*matched/total:.1f}%)")

# Create a lookup dict from FC24 data
fc24_lookup = {}
for _, row in merged_fc24[merged_fc24['nationality_name'].notna()].iterrows():
    fc24_lookup[row['Player ID']] = {
        'nationality': row['nationality_name'],
        'preferred_foot': row['preferred_foot'],
        'height_cm': row['height_cm'],
        'weight_kg': row['weight_kg'],
        'potential': row['potential'],
        'weak_foot': row['weak_foot'],
        'skill_moves': row['skill_moves'],
        'work_rate': row['work_rate'],
        'intl_reputation': row['international_reputation'],
        'value_eur': row['value_eur'],
        'wage_eur': row['wage_eur'],
        'full_name': row['long_name'],
        'dob': row['dob'],
    }

# Also add nationality from Nations Cup data for WC players
print("  Adding nationality from Nations Cup team membership...")
wc_mask = master['Player ID'].astype(str).str.startswith('P-')
wc_players = master[wc_mask][['Player ID', 'Player Name', 'Team Name']].drop_duplicates('Player ID')
nc_nationality = {}
for _, row in wc_players.iterrows():
    nc_nationality[row['Player ID']] = row['Team Name']
print(f"  Nations Cup players with nationality: {len(nc_nationality)}")

# Add nationality columns to master
def get_nationality(row):
    pid = safe_int(row['Player ID_orig'])
    if pid in fc24_lookup:
        return fc24_lookup[pid]['nationality']
    pid_str = str(row['Player ID_orig'])
    if pid_str in nc_nationality:
        return nc_nationality[pid_str]
    if row['Player ID_orig'] in nc_nationality:
        return nc_nationality[row['Player ID_orig']]
    return None

master['Nationality'] = master.apply(get_nationality, axis=1)
nat_coverage = master['Nationality'].notna().sum()
print(f"  Nationality coverage: {nat_coverage}/{len(master)} ({100*nat_coverage/len(master):.1f}%)")

# Add other FC24 fields
for field, fc24_key in [('Preferred Foot', 'preferred_foot'), ('Height (cm)', 'height_cm'),
                         ('Weight (kg)', 'weight_kg'), ('Potential', 'potential'),
                         ('Weak Foot', 'weak_foot'), ('Skill Moves', 'skill_moves'),
                         ('Work Rate', 'work_rate'), ('International Reputation', 'intl_reputation')]:
    def get_field(row, key=fc24_key):
        pid = safe_int(row['Player ID_orig'])
        if pid in fc24_lookup:
            return fc24_lookup[pid].get(key)
        return None
    master[field] = master.apply(get_field, axis=1)
    coverage = master[field].notna().sum()
    print(f"  {field}: {coverage}/{len(master)} ({100*coverage/len(master):.1f}%)")

# ═══════════════════════════════════════════════════════════════════
# STEP 3: Merge Transfermarkt career stats
# ═══════════════════════════════════════════════════════════════════

print("\nSTEP 3: Merging Transfermarkt career stats...")
tm_players = pd.read_csv(TM_PLAYERS_PATH, low_memory=False)
print(f"  Loading appearances (1.9M rows)...")
tm_app = pd.read_csv(TM_APP_PATH, low_memory=False)
print(f"  Loaded: {len(tm_app)} appearances")

# Aggregate career totals
career_stats = tm_app.groupby('player_id').agg(
    career_goals=('goals', 'sum'),
    career_assists=('assists', 'sum'),
    career_appearances=('appearance_id', 'count'),
    career_yellows=('yellow_cards', 'sum'),
    career_reds=('red_cards', 'sum'),
    career_minutes=('minutes_played', 'sum')
).reset_index()
print(f"  Career stats computed for {len(career_stats)} players")

# Build TM lookup by normalized name
tm_lookup = {}
tm_players_with_stats = tm_players.merge(career_stats, on='player_id', how='inner')
for _, row in tm_players_with_stats.iterrows():
    norm = normalize_name(row['name'])
    if norm:
        if norm not in tm_lookup or row['career_goals'] > tm_lookup[norm].get('career_goals', 0):
            tm_lookup[norm] = {
                'tm_id': row['player_id'],
                'career_goals': int(row['career_goals']),
                'career_assists': int(row['career_assists']),
                'career_appearances': int(row['career_appearances']),
                'career_yellows': int(row['career_yellows']),
                'career_reds': int(row['career_reds']),
                'career_minutes': int(row['career_minutes']),
                'height_in_cm': row.get('height_in_cm'),
                'foot': row.get('foot'),
                'country_of_citizenship': row.get('country_of_citizenship'),
                'market_value': row.get('highest_market_value_in_eur'),
            }
    # Also index by pretty_name
    if 'pretty_name' in row.index and pd.notna(row.get('pretty_name')):
        pnorm = normalize_name(row['pretty_name'])
        if pnorm and pnorm not in tm_lookup:
            tm_lookup[pnorm] = tm_lookup.get(norm, {})

print(f"  TM lookup index: {len(tm_lookup)} normalized names")

# Match our players to TM
def match_tm(player_name):
    norm = normalize_name(player_name)
    if norm in tm_lookup:
        return tm_lookup[norm]
    # Try surname only (last word)
    # Don't do this - too many false positives
    return None

# Get unique players
unique_players = master[['Player ID_orig', 'Player Name']].drop_duplicates('Player ID_orig')
tm_matched = 0
tm_data = {}
for _, row in unique_players.iterrows():
    result = match_tm(row['Player Name'])
    if result:
        tm_data[row['Player ID_orig']] = result
        tm_matched += 1

print(f"  Matched: {tm_matched}/{len(unique_players)} ({100*tm_matched/len(unique_players):.1f}%)")

# Add career stat columns
for field, tm_key in [('Career Goals', 'career_goals'), ('Career Assists', 'career_assists'),
                       ('Career Appearances', 'career_appearances'),
                       ('Career Yellow Cards', 'career_yellows'), ('Career Red Cards', 'career_reds'),
                       ('Career Minutes', 'career_minutes')]:
    def get_tm_field(row, key=tm_key):
        pid = row['Player ID_orig']
        if pid in tm_data:
            return tm_data[pid].get(key)
        return None
    master[field] = master.apply(get_tm_field, axis=1)

goals_coverage = master['Career Goals'].notna().sum()
print(f"  Career Goals coverage: {goals_coverage}/{len(master)} ({100*goals_coverage/len(master):.1f}%)")

# Fill in missing nationality/height/foot from TM where FC24 didn't have it
for _, row in master[master['Nationality'].isna()].iterrows():
    pid = row['Player ID_orig']
    if pid in tm_data and tm_data[pid].get('country_of_citizenship'):
        master.loc[master['Player ID_orig'] == pid, 'Nationality'] = tm_data[pid]['country_of_citizenship']

for _, row in master[master['Height (cm)'].isna()].iterrows():
    pid = row['Player ID_orig']
    if pid in tm_data and tm_data[pid].get('height_in_cm') and not pd.isna(tm_data[pid]['height_in_cm']):
        master.loc[master['Player ID_orig'] == pid, 'Height (cm)'] = tm_data[pid]['height_in_cm']

for _, row in master[master['Preferred Foot'].isna()].iterrows():
    pid = row['Player ID_orig']
    if pid in tm_data and tm_data[pid].get('foot'):
        foot = tm_data[pid]['foot']
        if isinstance(foot, str):
            master.loc[master['Player ID_orig'] == pid, 'Preferred Foot'] = foot.capitalize()

# ═══════════════════════════════════════════════════════════════════
# STEP 4: Add club → country mapping
# ═══════════════════════════════════════════════════════════════════

print("\nSTEP 4: Adding club country mapping...")
master['Club Country'] = master['Team Name'].map(CLUB_COUNTRY_MAP)

# For Nations Cup, the "club" IS the country
nc_mask = master['Mode'] == 'Nations Cup'
master.loc[nc_mask, 'Club Country'] = master.loc[nc_mask, 'Team Name']

cc_coverage = master['Club Country'].notna().sum()
unmapped = master[master['Club Country'].isna()]['Team Name'].unique()
print(f"  Club Country coverage: {cc_coverage}/{len(master)} ({100*cc_coverage/len(master):.1f}%)")
if len(unmapped) > 0:
    print(f"  Unmapped teams: {list(unmapped)}")

# ═══════════════════════════════════════════════════════════════════
# STEP 5: Compute derived fields
# ═══════════════════════════════════════════════════════════════════

print("\nSTEP 5: Computing derived fields...")

# Generic competition name
def get_generic_league(mode, club_country):
    if mode == 'Nations Cup':
        return 'World Championship'
    elif club_country:
        return f"{club_country} First Division"
    else:
        return mode

master['Competition Name'] = master.apply(lambda r: get_generic_league(r['Mode'], r.get('Club Country')), axis=1)

# Display name (2-3 letter abbreviation already exists as Team Code)
# Market value (derived from §6.4 formula)
def compute_market_value(row):
    ovr = row['Overall Rating (OVR)']
    age = row['Age']
    pos = row['Primary Position']

    if pd.isna(ovr) or pd.isna(age):
        return None

    age = int(age)
    ovr = int(ovr)

    # Base value in millions
    base = 0.35 * (1.115 ** (ovr - 60))

    # Age factor
    if age <= 21: age_f = 1.45
    elif age <= 24: age_f = 1.35
    elif age <= 27: age_f = 1.15
    elif age <= 30: age_f = 0.85
    elif age <= 32: age_f = 0.55
    elif age <= 34: age_f = 0.30
    else: age_f = 0.15

    # Position factor
    pos_factors = {
        'ST': 1.25, 'CF': 1.25, 'LW': 1.25, 'RW': 1.25,
        'CAM': 1.15, 'LM': 1.10, 'RM': 1.10,
        'CM': 1.0, 'CDM': 0.95,
        'CB': 0.90, 'LB': 0.85, 'RB': 0.85, 'LWB': 0.85, 'RWB': 0.85,
        'GK': 0.75
    }
    pos_f = pos_factors.get(pos, 1.0)

    value = base * age_f * pos_f
    return round(value, 2)

master['Market Value (M)'] = master.apply(compute_market_value, axis=1)
mv_coverage = master['Market Value (M)'].notna().sum()
print(f"  Market Value coverage: {mv_coverage}/{len(master)} ({100*mv_coverage/len(master):.1f}%)")

# Sanity check
test_cases = master[(master['Overall Rating (OVR)'] >= 90) & (master['Age'].notna())].head(10)
print("  Value sanity check (90+ rated):")
for _, row in test_cases.iterrows():
    print(f"    {row['Player Name']} ({row['Primary Position']}, {int(row['Age'])}y, OVR {row['Overall Rating (OVR)']}): {row['Market Value (M)']:.1f}M")

# ═══════════════════════════════════════════════════════════════════
# STEP 6: Export to SQLite
# ═══════════════════════════════════════════════════════════════════

print("\nSTEP 6: Exporting to SQLite...")

# Clean up temp columns
master = master.drop(columns=['_merge_id', 'Player ID_orig'], errors='ignore')

# Rename columns for SQL-friendliness
col_map = {
    'Mode': 'mode',
    'Squad ID': 'squad_id',
    'Team Code': 'team_code',
    'Team Name': 'team_name',
    'Season / Year': 'season',
    'Player ID': 'player_id',
    'Player Name': 'player_name',
    'Overall Rating (OVR)': 'overall',
    'Display Position': 'display_position',
    'Primary Position': 'primary_position',
    'All Eligible Positions': 'all_positions',
    'Age': 'age',
    'Shirt Number': 'shirt_number',
    'Pace / Diving (PAC)': 'pace',
    'Shooting / Handling (SHO)': 'shooting',
    'Passing / Kicking (PAS)': 'passing',
    'Dribbling / Reflexes (DRI)': 'dribbling',
    'Defending / Speed (DEF)': 'defending',
    'Physicality / Positioning (PHY)': 'physicality',
    'Is Goalkeeper': 'is_goalkeeper',
    'Squad Rating Weight': 'squad_weight',
    'Data Source / ID Type': 'data_source',
    'Nationality': 'nationality',
    'Preferred Foot': 'preferred_foot',
    'Height (cm)': 'height_cm',
    'Weight (kg)': 'weight_kg',
    'Potential': 'potential',
    'Weak Foot': 'weak_foot',
    'Skill Moves': 'skill_moves',
    'Work Rate': 'work_rate',
    'International Reputation': 'intl_reputation',
    'Career Goals': 'career_goals',
    'Career Assists': 'career_assists',
    'Career Appearances': 'career_appearances',
    'Career Yellow Cards': 'career_yellows',
    'Career Red Cards': 'career_reds',
    'Career Minutes': 'career_minutes',
    'Club Country': 'club_country',
    'Competition Name': 'competition_name',
    'Market Value (M)': 'market_value_millions',
}
master = master.rename(columns=col_map)

# Teams catalog
teams_col_map = {
    'Mode': 'mode',
    'Squad ID': 'squad_id',
    'Team Code': 'team_code',
    'Team Name': 'team_name',
    'Season / Year': 'season',
    'Squad Rating Weight': 'squad_weight',
    'Total Players': 'total_players',
    'Average Squad OVR': 'avg_ovr',
    'Top Star Player': 'top_star',
    'Goalkeepers': 'gk_count',
    'Defenders': 'def_count',
    'Midfielders': 'mid_count',
    'Forwards': 'fwd_count',
    'Primary Jersey Color': 'primary_color',
    'Secondary Jersey Color': 'secondary_color',
}
teams_cat = teams_cat.rename(columns=teams_col_map)
teams_cat['club_country'] = teams_cat['team_name'].map(CLUB_COUNTRY_MAP)
nc_teams = teams_cat['mode'] == 'Nations Cup'
teams_cat.loc[nc_teams, 'club_country'] = teams_cat.loc[nc_teams, 'team_name']

# Write to SQLite
db_path = os.path.join(OUT_DIR, "players.db")
if os.path.exists(db_path):
    os.remove(db_path)

conn = sqlite3.connect(db_path)

# Players table
master.to_sql('players', conn, index=False, if_exists='replace')
print(f"  Written: players table ({len(master)} rows)")

# Teams table
teams_cat.to_sql('teams', conn, index=False, if_exists='replace')
print(f"  Written: teams table ({len(teams_cat)} rows)")

# Create indices
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_id ON players(player_id)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_name ON players(player_name)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_code, season)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_overall ON players(overall)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_position ON players(primary_position)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_mode ON players(mode)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_players_squad ON players(squad_id)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_teams_squad ON teams(squad_id)")
conn.execute("CREATE INDEX IF NOT EXISTS idx_teams_code ON teams(team_code)")

# Create FTS5 virtual table for player search
conn.execute("DROP TABLE IF EXISTS players_fts")
conn.execute("""
    CREATE VIRTUAL TABLE players_fts USING fts5(
        player_id,
        player_name,
        team_name,
        nationality,
        primary_position,
        overall,
        content='players',
        content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2'
    )
""")
conn.execute("""
    INSERT INTO players_fts(rowid, player_id, player_name, team_name, nationality, primary_position, overall)
    SELECT rowid, player_id, player_name, team_name, nationality, primary_position, overall FROM players
""")
print(f"  Created FTS5 search index")

conn.commit()

# Test FTS search
cursor = conn.execute("""
    SELECT player_name, team_name, overall, nationality
    FROM players_fts
    WHERE players_fts MATCH 'messi'
    LIMIT 5
""")
results = cursor.fetchall()
print(f"  FTS test 'messi': {results}")

cursor = conn.execute("""
    SELECT player_name, team_name, overall, nationality
    FROM players_fts
    WHERE players_fts MATCH 'lampard'
    LIMIT 5
""")
results = cursor.fetchall()
print(f"  FTS test 'lampard': {results}")

conn.close()

db_size = os.path.getsize(db_path) / (1024*1024)
print(f"\n  Database size: {db_size:.1f} MB")

# ═══════════════════════════════════════════════════════════════════
# FINAL COVERAGE REPORT
# ═══════════════════════════════════════════════════════════════════

print("\n" + "=" * 60)
print("ENRICHMENT COMPLETE — FINAL COVERAGE")
print("=" * 60)

total = len(master)
fields = [
    ('player_name', 'Player Name'),
    ('overall', 'Overall Rating'),
    ('primary_position', 'Position'),
    ('age', 'Age'),
    ('nationality', 'Nationality'),
    ('preferred_foot', 'Preferred Foot'),
    ('height_cm', 'Height'),
    ('weight_kg', 'Weight'),
    ('potential', 'Potential'),
    ('career_goals', 'Career Goals'),
    ('career_assists', 'Career Assists'),
    ('career_appearances', 'Career Appearances'),
    ('club_country', 'Club Country'),
    ('market_value_millions', 'Market Value'),
    ('pace', 'PAC'),
    ('shooting', 'SHO'),
    ('passing', 'PAS'),
    ('dribbling', 'DRI'),
    ('defending', 'DEF'),
    ('physicality', 'PHY'),
]

print(f"\n{'Field':<25} {'Coverage':>10} {'%':>8}")
print("-" * 45)
for col, label in fields:
    if col in master.columns:
        cov = master[col].notna().sum()
        pct = 100 * cov / total
        print(f"{label:<25} {cov:>10,} {pct:>7.1f}%")

print(f"\nTotal rows: {total:,}")
print(f"Database: {db_path}")
print(f"Size: {db_size:.1f} MB")
print("\nDONE!")
