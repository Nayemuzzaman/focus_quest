/// Exception thrown when a focus quest operation is invalid.
class FocusQuestException implements Exception {
  /// Creates an exception with a user-readable [message].
  const FocusQuestException(this.message);

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'FocusQuestException: $message';
}
