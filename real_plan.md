"# Pre-Fix 19: Career Overhaul & Game Polish — Implementation Plan

This plan covers **10 sequential fixes (Fix 18a through 18j)**, each verified with `flutter analyze` + `flutter test` + APK build before moving to the next. A final **Fix 19 (Verification & Polish)** is appended.

---

## Open Questions

> [!IMPORTANT]
> **Q1: Premier League 20 teams — which 10 to add?**
> The database has these English club teams with modern rosters (season ≥ 2022): Bournemouth, Brentford, Brighton, Burnley, Crystal Palace, Everton, Fulham, Ipswich Town, Leeds United, Leicester City, Liverpool, Luton Town, Man City, Man United, Newcastle, Norwich City, Nottingham Forest, Sheffield United, Southampton, Sunderland, Tottenham, Watford, West Ham, Wolverhampton Wanderers + the current 10 (Arsenal, Aston Villa, Chelsea).
>
> **Proposed 20-club Premier League roster:**
> Arsenal, Aston Villa, AFC Bournemouth, Brentford, Brighton & Hove Albion, Burnley, Chelsea, Crystal Palace, Everton, Fulham, Liverpool, Manchester City, Manchester United, Newcastle United, Nottingham Forest, Tottenham Hotspur, West Ham United, Wolverhampton Wanderers, Ipswich Town, Leicester City
>
> Does this look right, or do you want different clubs?

> [!IMPORTANT]
> **Q2: UCL — which teams qualify, and how does it integrate?**
> You mentioned "other competitions such as UCL". The simplest approach is:
> - At season start, the **top 4 clubs** from the previous season's league table (or a seeded pot of 8 elite clubs for Season 1) enter a simplified **UCL Group Stage → Knockout** tournament running in parallel with league fixtures.
> - UCL matches are played on separate "midweek" matchdays interspersed between league gameweeks.
> - Stats are tracked separately per competition.
>
> Is this the right scope, or do you want a full 32/36-team UCL simulation?

> [!IMPORTANT]
> **Q3: Connections — ad-based hints**
> Currently the Connections game ("Four by Four") already shows a "One away!" SnackBar when 3/4 match. You want:\
<truncated 13796 bytes>