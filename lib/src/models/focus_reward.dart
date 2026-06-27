/// A reward earned for completing or partially completing a focus session.
class FocusReward {
  const FocusReward({
    required this.points,
    required this.experience,
    this.metadata = const {},
  });

  final int points;
  final int experience;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'points': points,
    'experience': experience,
    'metadata': metadata,
  };

  factory FocusReward.fromJson(Map<String, Object?> json) {
    return FocusReward(
      points: json['points'] as int? ?? 0,
      experience: json['experience'] as int? ?? 0,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}
