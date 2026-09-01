/// Mirrors GET /api/leaderboard/my-position's JSON shape.
class LeaderboardMyPosition {
  final int rank;
  final int totalPoints;
  final String sub;
  final int? rankChange;

  const LeaderboardMyPosition({
    required this.rank,
    required this.totalPoints,
    required this.sub,
    this.rankChange,
  });

  factory LeaderboardMyPosition.fromJson(Map<String, dynamic> json) {
    return LeaderboardMyPosition(
      rank: json['rank'] as int,
      totalPoints: json['total_points'] as int,
      sub: json['sub'] as String,
      rankChange: json['rank_change'] as int?,
    );
  }
}
