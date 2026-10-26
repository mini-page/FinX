/// Supported recurrence unit labels (case-insensitive).
enum RecurrenceUnit { day, week, month }

/// Parsed result from a `!` recurrence shortcode in the note field.
class RecurrenceParsed {
  const RecurrenceParsed({
    required this.count,
    required this.unit,
  });

  /// Number of intervals (1–365).
  final int count;

  /// The unit: day, week, or month.
  final RecurrenceUnit unit;

  /// A human-readable label, e.g. "Every 2 weeks".
  String get label {
    final unitLabel = switch (unit) {
      RecurrenceUnit.day => count == 1 ? 'day' : 'days',
      RecurrenceUnit.week => count == 1 ? 'week' : 'weeks',
      RecurrenceUnit.month => count == 1 ? 'month' : 'months',
    };
    return 'Every $count $unitLabel';
  }

  /// The `billingPeriod` string stored in the model.
  /// Format: `"<count>:<unit>"` e.g. `"2:week"`, `"12:month"`, `"1:day"`.
  String get encoded => '$count:${unit.name}';

  /// Calculates the next due date after [fromDate].
  DateTime nextDate(DateTime fromDate) {
    return switch (unit) {
      RecurrenceUnit.day => fromDate.add(Duration(days: count)),
      RecurrenceUnit.week => fromDate.add(Duration(days: count * 7)),
      RecurrenceUnit.month => _addMonths(fromDate, count),
    };
  }

  static DateTime _addMonths(DateTime date, int months) {
    int newMonth = date.month + months;
    int newYear = date.year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    final daysInNew = _daysInMonth(newYear, newMonth);
    return DateTime(newYear, newMonth, date.day.clamp(1, daysInNew));
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final leap = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return leap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceParsed && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'RecurrenceParsed($count ${unit.name})';
}

/// Parses a `!`-shortcode token (the part AFTER the `!` symbol).
///
/// Examples:
///   `"2week"` → `RecurrenceParsed(count: 2, unit: week)`
///   `"12days"` → `RecurrenceParsed(count: 12, unit: day)`
///   `"1month"` → `RecurrenceParsed(count: 1, unit: month)`
///   `"monthly"` → `RecurrenceParsed(count: 1, unit: month)`
///   `"weekly"` → `RecurrenceParsed(count: 1, unit: week)`
///   `"daily"` → `RecurrenceParsed(count: 1, unit: day)`
///
/// Returns `null` if the token doesn't match any recognisable pattern.
RecurrenceParsed? parseRecurrenceToken(String token) {
  if (token.isEmpty) return null;
  final lower = token.toLowerCase().trim();

  // Handle keyword aliases first
  if (lower == 'daily') return const RecurrenceParsed(count: 1, unit: RecurrenceUnit.day);
  if (lower == 'weekly') return const RecurrenceParsed(count: 1, unit: RecurrenceUnit.week);
  if (lower == 'monthly') return const RecurrenceParsed(count: 1, unit: RecurrenceUnit.month);
  if (lower == 'quarterly') return const RecurrenceParsed(count: 3, unit: RecurrenceUnit.month);
  if (lower == 'yearly' || lower == 'annual' || lower == 'annually') {
    return const RecurrenceParsed(count: 12, unit: RecurrenceUnit.month);
  }
  if (lower == 'biweekly' || lower == 'fortnightly') {
    return const RecurrenceParsed(count: 2, unit: RecurrenceUnit.week);
  }

  // Try pattern: digits followed by a unit label
  // e.g. "2week", "12days", "3months", "1 week", "14Day"
  final match = RegExp(r'^(\d+)\s*(days?|weeks?|months?)$').firstMatch(lower);
  if (match != null) {
    final count = int.tryParse(match.group(1)!) ?? 1;
    final unitStr = match.group(2)!;
    final unit = _parseUnit(unitStr);
    if (unit != null && count >= 1 && count <= 365) {
      return RecurrenceParsed(count: count, unit: unit);
    }
  }

  // Try encoded format: "2:week"
  final encodedMatch = RegExp(r'^(\d+):(day|week|month)$').firstMatch(lower);
  if (encodedMatch != null) {
    final count = int.tryParse(encodedMatch.group(1)!) ?? 1;
    final unit = _parseUnit(encodedMatch.group(2)!);
    if (unit != null) return RecurrenceParsed(count: count, unit: unit);
  }

  return null;
}

/// Decode a stored `billingPeriod` string back to [RecurrenceParsed].
///
/// Handles both the new encoded format `"2:week"` and legacy strings
/// like `"weekly"`, `"monthly"`, `"quarterly"`, `"yearly"`.
RecurrenceParsed decodeRecurrence(String billingPeriod) {
  return parseRecurrenceToken(billingPeriod) ??
      const RecurrenceParsed(count: 1, unit: RecurrenceUnit.month);
}

RecurrenceUnit? _parseUnit(String s) {
  final lower = s.toLowerCase();
  if (lower.startsWith('day')) return RecurrenceUnit.day;
  if (lower.startsWith('week')) return RecurrenceUnit.week;
  if (lower.startsWith('month')) return RecurrenceUnit.month;
  return null;
}
