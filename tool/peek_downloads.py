"""Peek at the downloaded supplementary data files to understand schemas."""
import pandas as pd
import sys, os

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

# 1. Transfermarkt players.csv
print("=" * 80)
print("TRANSFERMARKT players.csv")
print("=" * 80)
tm_players = pd.read_csv("data_sources/players.csv", low_memory=False)
print(f"Shape: {tm_players.shape}")
print(f"Columns: {list(tm_players.columns)}")
print(f"\nFirst 3 rows (key columns):")
key_cols = ['player_id', 'name', 'pretty_name', 'country_of_birth', 'country_of_citizenship',
            'date_of_birth', 'position', 'sub_position', 'foot', 'height_in_cm',
            'market_value_in_eur', 'current_club_name', 'current_club_id',
            'last_season', 'highest_market_value_in_eur']
available_cols = [c for c in key_cols if c in tm_players.columns]
print(tm_players[available_cols].head(3).to_string())
print(f"\nTotal unique player_ids: {tm_players['player_id'].nunique()}")

# Check for sofifa_id or EA FIFA link
if 'sofifa_id' in tm_players.columns:
    print("sofifa_id column EXISTS!")
else:
    print("No sofifa_id column - will need name matching")

print()

# 2. Transfermarkt appearances.csv
print("=" * 80)
print("TRANSFERMARKT appearances.csv")
print("=" * 80)
tm_app = pd.read_csv("data_sources/appearances.csv", low_memory=False, nrows=100000)
print(f"Shape (first 100k): {tm_app.shape}")
print(f"Columns: {list(tm_app.columns)}")
key_cols = ['player_id', 'player_name', 'goals', 'assists', 'yellow_cards', 'red_cards', 'minutes_played']
available_cols = [c for c in key_cols if c in tm_app.columns]
print(f"\nSample:")
print(tm_app[available_cols].head(5).to_string())

# Get career totals for a well-known player
print("\n--- Quick career totals test ---")
# Find Messi or Ronaldo
for test_name in ['Lionel Messi', 'Cristiano Ronaldo', 'Harry Kane']:
    matches = tm_app[tm_app['player_name'].str.contains(test_name, case=False, na=False)] if 'player_name' in tm_app.columns else pd.DataFrame()
    if len(matches) == 0 and 'player_id' in tm_app.columns:
        # Try by ID from players table
        pid_matches = tm_players[tm_players['name'].str.contains(test_name, case=False, na=False)]
        if len(pid_matches) > 0:
            pid = pid_matches.iloc[0]['player_id']
            matches = tm_app[tm_app['player_id'] == pid]
    if len(matches) > 0:
        goals = matches['goals'].sum() if 'goals' in matches.columns else '?'
        assists = matches['assists'].sum() if 'assists' in matches.columns else '?'
        apps = len(matches)
        print(f"  {test_name}: {apps} appearances, {goals} goals, {assists} assists (in first 100k rows)")
    else:
        print(f"  {test_name}: not found in first 100k rows")

print()

# 3. FC24 male_players.csv
print("=" * 80)
print("EA FC 24 male_players.csv")
print("=" * 80)
fc24 = pd.read_csv("data_sources/fc24/male_players.csv", low_memory=False)
print(f"Shape: {fc24.shape}")
print(f"Columns ({len(fc24.columns)} total):")
for c in fc24.columns:
    print(f"  {c}")

# Key columns we care about
key_cols = ['sofifa_id', 'short_name', 'long_name', 'player_positions',
            'nationality_name', 'preferred_foot', 'height_cm', 'weight_kg',
            'overall', 'potential', 'value_eur', 'wage_eur',
            'club_name', 'league_name', 'dob', 'age',
            'weak_foot', 'skill_moves', 'work_rate', 'body_type']
available_cols = [c for c in key_cols if c in fc24.columns]
print(f"\nKey columns available: {available_cols}")
print(f"\nSample (first 5):")
print(fc24[available_cols].head(5).to_string())

# Check match potential with our DB
print(f"\nTotal sofifa_ids: {fc24['sofifa_id'].nunique()}")
print(f"Total with preferred_foot: {fc24['preferred_foot'].notna().sum()}")
print(f"Total with height_cm: {fc24['height_cm'].notna().sum()}")
print(f"Total with nationality: {fc24['nationality_name'].notna().sum()}")
print(f"Total with weight_kg: {fc24['weight_kg'].notna().sum()}")

# 4. Transfers
print()
print("=" * 80)
print("TRANSFERMARKT transfers.csv")
print("=" * 80)
tm_transfers = pd.read_csv("data_sources/transfers.csv", low_memory=False, nrows=5)
print(f"Columns: {list(tm_transfers.columns)}")
print(tm_transfers.head().to_string())

print("\n\nDONE")
