import 'package:flutter/material.dart';
import '../config/api_config.dart';

class WeekDayStatus {
  final String label;
  final bool done;
  const WeekDayStatus(this.label, this.done);
}

class PassiveDay {
  final String month;
  final String day;
  final String steps;
  final String distance;
  final String points;
  const PassiveDay({
    required this.month,
    required this.day,
    required this.steps,
    required this.distance,
    required this.points,
  });
}

class LeaderboardEntry {
  final int rank;
  final String initials;
  final String name;
  // Null for a by_division-scope entry (a division has no photo of its
  // own) and for any employee who hasn't uploaded one yet.
  final String? photoUrl;
  final String sub;
  final String points;
  final bool isMe;
  const LeaderboardEntry({
    required this.rank,
    required this.initials,
    required this.name,
    this.photoUrl,
    required this.sub,
    required this.points,
    this.isMe = false,
  });

  /// Mirrors one entry of GET /api/leaderboard's JSON shape — initials and
  /// the thousands-formatted points string are derived client-side, same as
  /// Employee.initials.
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final photoUrl = json['photo_url'] as String?;
    return LeaderboardEntry(
      rank: json['rank'] as int,
      initials: _initialsOf(name),
      name: name,
      photoUrl: photoUrl != null ? ApiConfig.resolveAssetUrl(photoUrl) : null,
      sub: json['sub'] as String,
      points: _formatPoints(json['total_points'] as int),
      isMe: json['is_me'] as bool? ?? false,
    );
  }

  static String _initialsOf(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  static String _formatPoints(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class BadgeItem {
  final int id;
  final String name;
  final IconData icon;
  final String desc;
  final String req;
  final bool earned;
  final String? date;
  const BadgeItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.req,
    required this.earned,
    this.date,
  });
}
