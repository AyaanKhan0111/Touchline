import sqlite3

conn = sqlite3.connect('assets/database/football.db')
cursor = conn.cursor()
cursor.execute("SELECT player_id, player_name, team_name, overall, nationality, primary_position FROM players WHERE player_name LIKE '%Salah%'")
rows = cursor.fetchall()
print(f"Found {len(rows)} Salah rows:")
for r in rows:
    print(r)

print("\nSearch for 'salah' in FTS or search:")
cursor.execute("SELECT p.player_id, p.player_name, p.team_name, p.overall, p.nationality FROM players p WHERE p.player_name LIKE '%salah%' GROUP BY p.player_name")
for r in cursor.fetchall():
    print(r)
