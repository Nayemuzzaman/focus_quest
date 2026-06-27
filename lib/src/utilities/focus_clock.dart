abstract class FocusClock {
  DateTime now();
}

class SystemFocusClock implements FocusClock {
  const SystemFocusClock();

  @override
  DateTime now() => DateTime.now();
}

class FakeFocusClock implements FocusClock {
  FakeFocusClock({DateTime? initialTime})
    : _now = initialTime ?? DateTime(2024, 1, 1, 12);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void setNow(DateTime dateTime) {
    _now = dateTime;
  }
}
