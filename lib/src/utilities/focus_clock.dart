/// Supplies the current time for testable session calculations.
abstract class FocusClock {
  /// Returns the current timestamp.
  DateTime now();
}

/// Clock implementation backed by [DateTime.now].
class SystemFocusClock implements FocusClock {
  /// Creates a system clock.
  const SystemFocusClock();

  @override
  DateTime now() => DateTime.now();
}

/// Mutable clock for deterministic tests.
class FakeFocusClock implements FocusClock {
  /// Creates a fake clock at [initialTime] or a default timestamp.
  FakeFocusClock({DateTime? initialTime})
    : _now = initialTime ?? DateTime(2024, 1, 1, 12);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the fake clock forward by [duration].
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  /// Sets the fake clock to [dateTime].
  void setNow(DateTime dateTime) {
    _now = dateTime;
  }
}
