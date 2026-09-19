"""Assess match rates between our DB and supplementary datasets."""
import pandas as pd
import sys
sys.stdout.reconfigure(encoding='utf-8')

# Load our DB
print("Loading our database...")
our_db = pd.read_excel("Football_Database_Expanded.xlsx", sheet_name="All Players Master")
print(f"Our DB: {len(our_db)} rows, {our_db['Player ID'].nunique()} unique IDs")

# Split by ID type
our_numeric_ids = our_db[our_db['Player ID'].apply(lambda x: str(x).isdigit())]
our_wc_ids = our_db[our_db['Player ID'].astype(str).str.startswith('P-')]
print(f"  Numeric IDs (EA FIFA): {our_numeric_ids['Player ID'].nunique()}")
print(f"  World Cup IDs (P-): {our_wc_ids['Player ID'].nunique()}")

# Get unique numeric IDs
our_fifa_ids = set(our_numeric_ids['Player ID'].astype(int).unique())
print(f"  Unique numeric FIFA IDs: {len(our_fifa_ids)}")

# ── FC24 Dataset Match ──
print("\n=== FC24 DATASET MATCH ===")
fc24 = pd.read_csv("data_sources/fc24/male_players.csv", low_memory=False)
# Get unique fc24 player_ids (latest update only)
fc24_latest = fc24.sort_values('fifa_update', ascending=False).drop_duplicates('player_id')
fc24_ids = set(fc24_latest['player_id'].unique())
print(f"FC24 unique player_ids: {len(fc24_ids)}")

matched_fc24 = our_fifa_ids & fc24_ids
print(f"MATCHED (our FIFA ID in FC24): {len(matched_fc24)} / {len(our_fifa_ids)} ({100*len(matched_fc24)/len(our_fifa_ids):.1f}%)")

# What fields can we get from FC24 for matched players?
fc24_sample = fc24_latest[fc24_latest['player_id'].isin(list(matched_fc24)[:5])]
print(f"\nSample matched players:")
for _, row in fc24_sample.iterrows():
    print(f"  ID {row['player_id']}: {row['long_name']} | {row['nationality_name']} | {row['preferred_foot']} | {row['height_cm']}cm | {row['weight_kg']}kg")

# How many of our IDs are NOT in FC24? (retro/old players)
unmatched = our_fifa_ids - fc24_ids
print(f"\nUnmatched FIFA IDs (our DB but not in FC24): {len(unmatched)}")

# ── Transfermarkt Match ──
print("\n=== TRANSFERMARKT MATCH ===")
tm_players = pd.read_csv("data_sources/players.csv", low_memory=False)
tm_names = set(tm_players['name'].str.lower().unique())
print(f"Transfermarkt unique players: {len(tm_players)}")

# Since TM uses its own IDs, we need to name-match
our_names = our_db[['Player ID', 'Player Name']].drop_duplicates('Player ID')
our_name_set = set(our_names['Player Name'].str.lower().unique())

# Direct name match
direct_match = our_name_set & tm_names
print(f"Direct name match: {len(direct_match)} / {len(our_name_set)} ({100*len(direct_match)/len(our_name_set):.1f}%)")

# Try pretty_name too
if 'pretty_name' in tm_players.columns:
    tm_pretty = set(tm_players['pretty_name'].str.lower().dropna().unique())
    pretty_match = our_name_set & tm_pretty
    total_match = our_name_set & (tm_names | tm_pretty)
    print(f"Pretty name match: {len(pretty_match)}")
    print(f"Combined match (name OR pretty_name): {len(total_match)} ({100*len(total_match)/len(our_name_set):.1f}%)")

# Check career goals aggregation from appearances
print("\n=== CAREER STATS FROM APPEARANCES ===")
print("Loading full appearances (this may take a minute)...")
tm_app = pd.read_csv("data_sources/appearances.csv", low_memory=False)
print(f"Total appearances: {len(tm_app)}")

career_stats = tm_app.groupby('player_id').agg(
    total_goals=('goals', 'sum'),
    total_assists=('assists', 'sum'),
    total_appearances=('appearance_id', 'count'),
    total_yellows=('yellow_cards', 'sum'),
    total_reds=('red_cards', 'sum'),
    total_minutes=('minutes_played', 'sum')
).reset_index()

print(f"Players with career stats: {len(career_stats)}")

# Show top 10 by goals
top_scorers = career_stats.nlargest(15, 'total_goals').merge(tm_players[['player_id', 'name', 'country_of_citizenship']], on='player_id')
print(f"\nTop 15 all-time scorers (Transfermarkt appearances data):")
for _, row in top_scorers.iterrows():
    print(f"  {row['name']} ({row['country_of_citizenship']}): {int(row['total_goals'])} goals, {int(row['total_assists'])} assists, {int(row['total_appearances'])} apps")

# Test specific players
print("\n--- Test specific players ---")
for test_name in ['Cristiano Ronaldo', 'Lionel Messi', 'Harry Kane', 'Erling Haaland', 'Thierry Henry', 'Wayne Rooney']:
    pid_matches = tm_players[tm_players['name'].str.contains(test_name, case=False, na=False)]
    if len(pid_matches) > 0:
        pid = pid_matches.iloc[0]['player_id']
        stats = career_stats[career_stats['player_id'] == pid]
        if len(stats) > 0:
            s = stats.iloc[0]
            print(f"  {test_name} (TM ID {pid}): {int(s['total_goals'])} goals, {int(s['total_assists'])} assists, {int(s['total_appearances'])} apps")
        else:
            print(f"  {test_name}: ID found but no appearances")
    else:
        print(f"  {test_name}: not found in TM players")

print("\n=== TRANSFERS ===")
tm_transfers = pd.read_csv("data_sources/transfers.csv", low_memory=False)
print(f"Total transfer records: {len(tm_transfers)}")
print(f"Columns: {list(tm_transfers.columns)}")
# Sample
print(tm_transfers[['player_id', 'player_name', 'transfer_date', 'transfer_season', 'from_club_name', 'to_club_name', 'transfer_fee', 'market_value_in_eur']].head(5).to_string())

print("\nDONE")
