class NoriUser {
  const NoriUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.currentStreak,
    this.coins = 0,
    this.vacationModeEnabled = false,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int currentStreak;
  final int coins;
  final bool vacationModeEnabled;
  final String? avatarUrl;

  double get levelProgress =>
      xpForNextLevel == 0 ? 0 : xpIntoLevel / xpForNextLevel;

  NoriUser copyWith({
    int? level,
    int? totalXp,
    int? xpIntoLevel,
    int? currentStreak,
    int? coins,
    bool? vacationModeEnabled,
  }) {
    return NoriUser(
      id: id,
      name: name,
      username: username,
      email: email,
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      xpIntoLevel: xpIntoLevel ?? this.xpIntoLevel,
      xpForNextLevel: xpForNextLevel,
      currentStreak: currentStreak ?? this.currentStreak,
      coins: coins ?? this.coins,
      vacationModeEnabled: vacationModeEnabled ?? this.vacationModeEnabled,
      avatarUrl: avatarUrl,
    );
  }
}
