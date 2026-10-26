import 'package:flutter/material.dart';

/// Mock competition types (OPEN_DECISIONS.md still has "competition types &
/// scoring" open — these are placeholders so the screens have something to
/// show, not decided rules).
enum CompetitionType {
  /// Most consecutive days completing the habit.
  streak('Streak', 'Most consecutive days wins', Icons.local_fire_department),

  /// Most total completions in the window.
  total('Total', 'Most completions wins', Icons.format_list_numbered),

  /// First to reach a target count.
  race('Goal race', 'First to hit the target wins', Icons.flag);

  const CompetitionType(this.label, this.blurb, this.icon);

  final String label;
  final String blurb;
  final IconData icon;
}

enum CompetitionStatus { active, invited, past }

class Competition {
  const Competition({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.habitName,
    required this.icon,
    required this.color,
    required this.hostId,
    required this.participantIds,
    required this.progress,
    required this.targetCount,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.prizeXp = 100,
    this.proofRequired = true,
    this.circleId,
    this.submittedToday = false,
    this.invitedById,
  });

  final String id;
  final String title;
  final String description;
  final CompetitionType type;
  final String habitName;
  final IconData icon;
  final Color color;
  final String hostId;

  /// Includes 'me' unless the competition is an unanswered invite.
  final List<String> participantIds;

  /// SocialUser id → completions (or current streak for [CompetitionType.streak]).
  final Map<String, int> progress;
  final int targetCount;
  final DateTime startsAt;
  final DateTime endsAt;
  final CompetitionStatus status;
  final int prizeXp;
  final bool proofRequired;
  final String? circleId;

  /// Whether you already submitted today's proof.
  final bool submittedToday;
  final String? invitedById;

  int get durationDays => endsAt.difference(startsAt).inDays;

  /// Participants ranked by progress, highest first (ties keep list order).
  List<String> get standings {
    final ids = [...participantIds];
    ids.sort((a, b) => (progress[b] ?? 0).compareTo(progress[a] ?? 0));
    return ids;
  }

  int get myProgress => progress['me'] ?? 0;
  double get myFraction =>
      targetCount == 0 ? 0 : (myProgress / targetCount).clamp(0, 1);

  Duration get timeLeft => endsAt.difference(DateTime.now());

  String get timeLeftLabel {
    final left = timeLeft;
    if (left.isNegative) return 'Ended';
    if (left.inHours < 24) return 'Ends in ${left.inHours} hrs';
    return '${left.inDays} days left';
  }

  Competition copyWith({
    List<String>? participantIds,
    Map<String, int>? progress,
    CompetitionStatus? status,
    bool? submittedToday,
  }) {
    return Competition(
      id: id,
      title: title,
      description: description,
      type: type,
      habitName: habitName,
      icon: icon,
      color: color,
      hostId: hostId,
      participantIds: participantIds ?? this.participantIds,
      progress: progress ?? this.progress,
      targetCount: targetCount,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status ?? this.status,
      prizeXp: prizeXp,
      proofRequired: proofRequired,
      circleId: circleId,
      submittedToday: submittedToday ?? this.submittedToday,
      invitedById: invitedById,
    );
  }
}

/// What the create-competition wizard collects.
class CompetitionDraft {
  const CompetitionDraft({
    required this.title,
    required this.type,
    required this.habitName,
    required this.icon,
    required this.color,
    required this.targetCount,
    required this.durationDays,
    required this.inviteeIds,
    this.circleId,
  });

  final String title;
  final CompetitionType type;
  final String habitName;
  final IconData icon;
  final Color color;
  final int targetCount;
  final int durationDays;
  final List<String> inviteeIds;
  final String? circleId;
}
