/// Status of a game mode after data requirements validation
enum ModeStatus {
  go,       // All required fields present at >90% coverage
  improved, // Functional with enriched fields
  degrade,  // Playable with reduced ruleset
  defer,    // Data missing; hidden from UI
}

/// Identifiers for all game modes in Touchline
enum GameModeId {
  grid,
  bingo,
  connections,
  identikit,
  guessXi,
  buildXi,
  goalChase,
  higherLower,
  frankenstein,
  quiz,
  career,
  tournamentLab,
  dailyHub,
  careerPath,
  transferDeadline,
  squadDraft,
  ratingsAuction,
  statAttack,
  pyramid,
  blindXi,
  retroRewind,
}

/// Mode specification with data requirements per Section 5 of the Build Brief.
class ModeRequirements {
  final GameModeId id;
  final String title;
  final String subtitle;
  final String sectionRef;
  final List<String> requiredFields;
  final ModeStatus defaultStatus;
  final String statusNotes;

  const ModeRequirements({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sectionRef,
    required this.requiredFields,
    required this.defaultStatus,
    required this.statusNotes,
  });

  bool get isPlayable => defaultStatus != ModeStatus.defer;

  static const List<ModeRequirements> allModes = [
    ModeRequirements(
      id: GameModeId.grid,
      title: 'Grid',
      subtitle: 'The Nine (3×3 Category Cross)',
      sectionRef: '§5.1',
      requiredFields: ['club_alumni', 'position', 'nationality', 'preferred_foot'],
      defaultStatus: ModeStatus.improved,
      statusNotes: '98.3% nationality, 73.4% foot, rating bands, 50+ career goals.',
    ),
    ModeRequirements(
      id: GameModeId.bingo,
      title: 'Bingo',
      subtitle: 'Full House (5×5 Criteria Board)',
      sectionRef: '§5.2',
      requiredFields: ['height_cm', 'preferred_foot', 'nationality', 'overall'],
      defaultStatus: ModeStatus.improved,
      statusNotes: 'Height and foot available for 18,000+ players.',
    ),
    ModeRequirements(
      id: GameModeId.connections,
      title: 'Connections',
      subtitle: 'Four by Four (Hidden Groups)',
      sectionRef: '§5.3',
      requiredFields: ['nationality', 'preferred_foot', 'shirt_number', 'overall'],
      defaultStatus: ModeStatus.improved,
      statusNotes: 'Rich group variety with traps and tonal styling.',
    ),
    ModeRequirements(
      id: GameModeId.identikit,
      title: 'Guess the Player',
      subtitle: 'Identikit (Wordle-style Clues)',
      sectionRef: '§5.4',
      requiredFields: ['primary_position', 'nationality', 'preferred_foot', 'overall'],
      defaultStatus: ModeStatus.improved,
      statusNotes: '6-clue drip sequence with comparison feedback.',
    ),
    ModeRequirements(
      id: GameModeId.guessXi,
      title: 'Guess the XI',
      subtitle: 'Read the Teamsheet',
      sectionRef: '§5.5',
      requiredFields: ['squad_id', 'overall', 'primary_position'],
      defaultStatus: ModeStatus.degrade,
      statusNotes: 'Best XI synthesized per squad from 849 historical rosters.',
    ),
    ModeRequirements(
      id: GameModeId.buildXi,
      title: 'Build the XI',
      subtitle: 'Eleven Nations & Constraints',
      sectionRef: '§5.6',
      requiredFields: ['nationality', 'primary_position', 'overall'],
      defaultStatus: ModeStatus.improved,
      statusNotes: '98.3% nationality enables worldwide 11 Nations challenge.',
    ),
    ModeRequirements(
      id: GameModeId.goalChase,
      title: 'Goal Chase',
      subtitle: 'The Ton (Career Milestone Roulette)',
      sectionRef: '§5.7',
      requiredFields: ['career_goals', 'career_assists', 'career_appearances'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'UNLOCKED via Transfermarkt career statistics for 6,498 players.',
    ),
    ModeRequirements(
      id: GameModeId.higherLower,
      title: 'Higher or Lower',
      subtitle: 'Over / Under (Streak Challenge)',
      sectionRef: '§5.8',
      requiredFields: ['overall', 'career_goals', 'height_cm', 'market_value_millions'],
      defaultStatus: ModeStatus.improved,
      statusNotes: 'Stats include OVR, 6 core attrs, height, goals, and market value.',
    ),
    ModeRequirements(
      id: GameModeId.frankenstein,
      title: 'Build-a-Player',
      subtitle: 'Frankenstein XI (Attribute Draft)',
      sectionRef: '§5.9',
      requiredFields: ['pace', 'shooting', 'passing', 'dribbling', 'defending', 'physicality'],
      defaultStatus: ModeStatus.go,
      statusNotes: '100% coverage across all 24,651 player records.',
    ),
    ModeRequirements(
      id: GameModeId.quiz,
      title: 'Quiz',
      subtitle: 'The Interrogation (Tiered Trivia)',
      sectionRef: '§5.10',
      requiredFields: ['overall', 'team_name', 'primary_position', 'career_goals'],
      defaultStatus: ModeStatus.improved,
      statusNotes: 'Rich trivia pool spanning clubs, stats, ratings, and milestones.',
    ),
    ModeRequirements(
      id: GameModeId.career,
      title: 'Career Mode',
      subtitle: 'The Long Game (15-Season Campaign)',
      sectionRef: '§5.11',
      requiredFields: ['overall', 'primary_position', 'age', 'potential'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'Lightweight sim engine, youth potential scouting, transfer market.',
    ),
    ModeRequirements(
      id: GameModeId.tournamentLab,
      title: 'Tournament Lab',
      subtitle: 'The Simulator (Cup & League Sims)',
      sectionRef: '§5.12',
      requiredFields: ['team_code', 'avg_ovr', 'squad_id'],
      defaultStatus: ModeStatus.go,
      statusNotes: '849 teams available for seeded knockout and round-robin sims.',
    ),
    ModeRequirements(
      id: GameModeId.dailyHub,
      title: 'Daily Hub',
      subtitle: 'The Daily Card',
      sectionRef: '§5.13',
      requiredFields: ['overall', 'player_name'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'Daily seeded challenge card aggregating active puzzle modes.',
    ),
    ModeRequirements(
      id: GameModeId.careerPath,
      title: 'Career Path',
      subtitle: 'Guess by Club Journey',
      sectionRef: '§5.14.1',
      requiredFields: ['player_id', 'team_code', 'season'],
      defaultStatus: ModeStatus.degrade,
      statusNotes: 'Uses cross-season multi-club timeline for 1,000+ players.',
    ),
    ModeRequirements(
      id: GameModeId.transferDeadline,
      title: 'Transfer Deadline',
      subtitle: 'Fee & Destination Quiz',
      sectionRef: '§5.14.2',
      requiredFields: ['transfer_history'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'UNLOCKED via Transfermarkt transfer archives.',
    ),
    ModeRequirements(
      id: GameModeId.squadDraft,
      title: 'Squad Draft Duel',
      subtitle: 'Draft & Sim Confrontation',
      sectionRef: '§5.14.3',
      requiredFields: ['overall', 'primary_position', 'team_code'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'Pure Dart seeded match simulation engine.',
    ),
    ModeRequirements(
      id: GameModeId.ratingsAuction,
      title: 'Ratings Auction',
      subtitle: 'Budget Squad Building',
      sectionRef: '§5.14.4',
      requiredFields: ['overall', 'primary_position'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'Rating auction system utilizing derived market values.',
    ),
    ModeRequirements(
      id: GameModeId.statAttack,
      title: 'Stat Attack',
      subtitle: 'Top Trumps Card Duel',
      sectionRef: '§5.14.5',
      requiredFields: ['pace', 'shooting', 'passing', 'dribbling', 'defending', 'physicality'],
      defaultStatus: ModeStatus.go,
      statusNotes: '100% attribute data coverage.',
    ),
    ModeRequirements(
      id: GameModeId.pyramid,
      title: 'Pyramid',
      subtitle: 'Ascending Difficulty Clues',
      sectionRef: '§5.14.6',
      requiredFields: ['nationality', 'club_country', 'overall'],
      defaultStatus: ModeStatus.improved,
      statusNotes: 'Clues tiered by nationality, position, ratings, and clubs.',
    ),
    ModeRequirements(
      id: GameModeId.blindXi,
      title: 'Blind XI',
      subtitle: 'Position Blind Draw',
      sectionRef: '§5.14.7',
      requiredFields: ['overall', 'primary_position'],
      defaultStatus: ModeStatus.go,
      statusNotes: 'Pure position-based draft test.',
    ),
    ModeRequirements(
      id: GameModeId.retroRewind,
      title: 'Retro Rewind',
      subtitle: 'Historical League Standings',
      sectionRef: '§5.14.8',
      requiredFields: ['historical_league_tables'],
      defaultStatus: ModeStatus.defer,
      statusNotes: 'DEFERRED: Historical league final standings tables not present.',
    ),
  ];
}
