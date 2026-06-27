/// A reward earned for completing or partially completing a focus session.
class FocusReward {
  /// Creates a reward value.
  const FocusReward({
    required this.points,
    required this.experience,
    this.metadata = const {},
  });

  /// Points awarded by a session.
  final int points;

  /// Experience awarded by a session.
  final int experience;

  /// Custom reward values for app-specific game systems.
  final Map<String, Object?> metadata;

  /// Converts the reward into JSON-compatible values.
  Map<String, Object?> toJson() => {
    'points': points,
    'experience': experience,
    'metadata': metadata,
  };

  /// Restores a reward from JSON-compatible values.
  factory FocusReward.fromJson(Map<String, Object?> json) {
    return FocusReward(
      points: json['points'] as int? ?? 0,
      experience: json['experience'] as int? ?? 0,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}
