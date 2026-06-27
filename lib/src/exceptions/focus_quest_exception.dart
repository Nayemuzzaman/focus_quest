class FocusQuestException implements Exception {
  const FocusQuestException(this.message);

  final String message;

  @override
  String toString() => 'FocusQuestException: $message';
}
