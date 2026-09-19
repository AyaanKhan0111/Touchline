import sqlite3
import time
import sys
sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/db/players.db')
cur = conn.cursor()

start = time.time()
clubs = [
    'Manchester United', 'Manchester City', 'Arsenal', 'Liverpool',
    'Chelsea', 'Tottenham Hotspur', 'Aston Villa', 'Newcastle United',
    'Brighton & Hove Albion', 'West Ham United'
]

rosters = {}
for c in clubs:
    queryClub = 'Inter' if c == 'Inter Milan' else c
    cur.execute('''
        SELECT player_name
        FROM players
        WHERE team_name LIKE ?
        GROUP BY player_name
        ORDER BY MAX(season) DESC, MAX(overall) DESC
        LIMIT 11
    ''', [f'%{queryClub}%'])
    rosters[c] = [r[0] for r in cur.fetchall()]

elapsed = (time.time() - start) * 1000
print(f"Loaded 10 club rosters in {elapsed:.1f}ms:")
for c, squad in rosters.items():
    print(f"  {c:25}: {', '.join(squad[:4])}...")
