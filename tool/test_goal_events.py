import random
import sys
sys.stdout.reconfigure(encoding='utf-8')

def generate_goal_events(scorers_pool, goal_count):
    if not goal_count:
        return []
    
    minutes = sorted(random.sample(range(2, 92), min(goal_count, 90)))
    events = []
    for m in minutes:
        scorer = random.choice(scorers_pool) if scorers_pool else "Striker"
        is_pen = random.random() < 0.12
        events.append({
            'scorer': scorer,
            'minute': m,
            'pen': is_pen
        })
    return events

pool_arsenal = ['Bukayo Saka', 'Gabriel Jesus', 'Declan Rice', 'Martin Ødegaard', 'Gabriel Martinelli', 'William Saliba']
pool_chelsea = ['Cole Palmer', 'Raheem Sterling', 'Moisés Caicedo', 'Enzo Fernández', 'Nicolas Jackson']

print("Arsenal goals:")
for g in generate_goal_events(pool_arsenal, 3):
    pen_str = " (pen)" if g['pen'] else ""
    print(f"  ⚽ {g['scorer']} {g['minute']}'{pen_str}")

print("\nChelsea goals:")
for g in generate_goal_events(pool_chelsea, 2):
    pen_str = " (pen)" if g['pen'] else ""
    print(f"  ⚽ {g['scorer']} {g['minute']}'{pen_str}")
