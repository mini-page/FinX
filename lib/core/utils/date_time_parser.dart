import 'package:flutter/foundation.dart';

@immutable
class ParsedDateTimeResult {
  const ParsedDateTimeResult({
    this.dateTime,
    required this.cleanedText,
    this.hasDate = false,
    this.hasTime = false,
  });

  final DateTime? dateTime;
  final String cleanedText;
  final bool hasDate;
  final bool hasTime;
}

/// Natural language date and time parser for Expense logs, OmniBox, and Voice Assistant.
class DateTimeParser {
  DateTimeParser._();

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  static const Map<String, int> _weekdayMap = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  /// Parses date and time from natural text [input] and returns the resolved
  /// [DateTime] along with the cleaned text.
  static ParsedDateTimeResult parse(String input, {DateTime? referenceNow}) {
    if (input.trim().isEmpty) {
      return const ParsedDateTimeResult(cleanedText: '');
    }

    final now = referenceNow ?? DateTime.now();
    var workingText = input;

    DateTime? resolvedDate;
    int? resolvedHour;
    int? resolvedMinute;
    bool hasDate = false;
    bool hasTime = false;

    // ── 1. Relative multi-word date patterns ──
    final dayBeforeYesterdayRegex = RegExp(r'\b(the\s+)?day\s+before\s+yesterday\b', caseSensitive: false);
    if (dayBeforeYesterdayRegex.hasMatch(workingText)) {
      resolvedDate = now.subtract(const Duration(days: 2));
      hasDate = true;
      workingText = workingText.replaceAll(dayBeforeYesterdayRegex, ' ');
    }

    final dayAfterTomorrowRegex = RegExp(r'\b(the\s+)?day\s+after\s+tomorrow\b', caseSensitive: false);
    if (!hasDate && dayAfterTomorrowRegex.hasMatch(workingText)) {
      resolvedDate = now.add(const Duration(days: 2));
      hasDate = true;
      workingText = workingText.replaceAll(dayAfterTomorrowRegex, ' ');
    }

    // ── 2. Single-word relative dates ──
    if (!hasDate) {
      final yesterdayRegex = RegExp(r'\b(yesterday|yday)\b', caseSensitive: false);
      if (yesterdayRegex.hasMatch(workingText)) {
        resolvedDate = now.subtract(const Duration(days: 1));
        hasDate = true;
        workingText = workingText.replaceAll(yesterdayRegex, ' ');
      }
    }

    if (!hasDate) {
      final tomorrowRegex = RegExp(r'\b(tomorrow|tmrw)\b', caseSensitive: false);
      if (tomorrowRegex.hasMatch(workingText)) {
        resolvedDate = now.add(const Duration(days: 1));
        hasDate = true;
        workingText = workingText.replaceAll(tomorrowRegex, ' ');
      }
    }

    if (!hasDate) {
      final todayRegex = RegExp(r'\b(today|tonight)\b', caseSensitive: false);
      if (todayRegex.hasMatch(workingText)) {
        resolvedDate = now;
        hasDate = true;
        workingText = workingText.replaceAll(todayRegex, ' ');
      }
    }

    // ── 3. Weekday patterns: "last friday", "next monday", "this sunday", "on wednesday" ──
    if (!hasDate) {
      final weekdayRegex = RegExp(
        r'\b(?:(last|past|next|this|on)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
        caseSensitive: false,
      );
      final match = weekdayRegex.firstMatch(workingText);
      if (match != null) {
        final modifier = match.group(1)?.toLowerCase();
        final dayStr = match.group(2)!.toLowerCase();
        final targetWeekday = _weekdayMap[dayStr];
        if (targetWeekday != null) {
          int diff = targetWeekday - now.weekday;
          if (modifier == 'last' || modifier == 'past') {
            if (diff >= 0) diff -= 7;
          } else if (modifier == 'next') {
            if (diff <= 0) diff += 7;
          } else {
            // "this" or "on"
            if (diff > 0) {
              // upcoming day in current cycle
            } else if (diff < 0) {
              // past day this week
            }
          }
          resolvedDate = now.add(Duration(days: diff));
          hasDate = true;
          workingText = workingText.replaceRange(match.start, match.end, ' ');
        }
      }
    }

    // ── 4. Explicit dates: "15th oct(ober) 2026", "oct 15", "15/10/2026" ──
    if (!hasDate) {
      // e.g. "15th oct" or "15 october 2026"
      final dayMonthRegex = RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s+(\d{4}))?\b',
        caseSensitive: false,
      );
      final match = dayMonthRegex.firstMatch(workingText);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        final monthStr = match.group(2)?.toLowerCase() ?? '';
        final month = _monthMap[monthStr];
        final year = int.tryParse(match.group(3) ?? '') ?? now.year;
        if (day != null && month != null && day >= 1 && day <= 31) {
          resolvedDate = DateTime(year, month, day);
          hasDate = true;
          workingText = workingText.replaceRange(match.start, match.end, ' ');
        }
      }
    }

    if (!hasDate) {
      // e.g. "oct(ober) 15th, 2026"
      final monthDayRegex = RegExp(
        r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?\b',
        caseSensitive: false,
      );
      final match = monthDayRegex.firstMatch(workingText);
      if (match != null) {
        final monthStr = match.group(1)?.toLowerCase() ?? '';
        final month = _monthMap[monthStr];
        final day = int.tryParse(match.group(2) ?? '');
        final year = int.tryParse(match.group(3) ?? '') ?? now.year;
        if (day != null && month != null && day >= 1 && day <= 31) {
          resolvedDate = DateTime(year, month, day);
          hasDate = true;
          workingText = workingText.replaceRange(match.start, match.end, ' ');
        }
      }
    }

    if (!hasDate) {
      // e.g. 15/10/2026 or 15-10
      final numericDateRegex = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?\b');
      final match = numericDateRegex.firstMatch(workingText);
      if (match != null) {
        final part1 = int.tryParse(match.group(1) ?? '') ?? 0;
        final part2 = int.tryParse(match.group(2) ?? '') ?? 0;
        var year = int.tryParse(match.group(3) ?? '') ?? now.year;
        if (year < 100) year += 2000;
        if (part1 >= 1 && part1 <= 31 && part2 >= 1 && part2 <= 12) {
          resolvedDate = DateTime(year, part2, part1);
          hasDate = true;
          workingText = workingText.replaceRange(match.start, match.end, ' ');
        }
      }
    }

    // ── 5. Time Expressions ──
    // e.g. "at 4pm", "4:30 pm", "10am", "at 14:00"
    final timeAmPmRegex = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    );
    final amPmMatch = timeAmPmRegex.firstMatch(workingText);
    if (amPmMatch != null) {
      var hour = int.tryParse(amPmMatch.group(1) ?? '') ?? 0;
      final minute = int.tryParse(amPmMatch.group(2) ?? '') ?? 0;
      final meridiem = amPmMatch.group(3)!.toLowerCase();
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      resolvedHour = hour;
      resolvedMinute = minute;
      hasTime = true;
      workingText = workingText.replaceRange(amPmMatch.start, amPmMatch.end, ' ');
    } else {
      // 24-hour time: "at 14:30"
      final time24Regex = RegExp(r'\bat\s+(\d{1,2}):(\d{2})\b', caseSensitive: false);
      final t24Match = time24Regex.firstMatch(workingText);
      if (t24Match != null) {
        final hour = int.tryParse(t24Match.group(1) ?? '') ?? 0;
        final minute = int.tryParse(t24Match.group(2) ?? '') ?? 0;
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          resolvedHour = hour;
          resolvedMinute = minute;
          hasTime = true;
          workingText = workingText.replaceRange(t24Match.start, t24Match.end, ' ');
        }
      }
    }

    // Fuzzy time phrases
    if (!hasTime) {
      final morningRegex = RegExp(r'\b(in\s+the\s+morning|this\s+morning)\b', caseSensitive: false);
      if (morningRegex.hasMatch(workingText)) {
        resolvedHour = 9;
        resolvedMinute = 0;
        hasTime = true;
        workingText = workingText.replaceAll(morningRegex, ' ');
      }
    }
    if (!hasTime) {
      final afternoonRegex = RegExp(r'\b(in\s+the\s+afternoon|this\s+afternoon)\b', caseSensitive: false);
      if (afternoonRegex.hasMatch(workingText)) {
        resolvedHour = 14;
        resolvedMinute = 0;
        hasTime = true;
        workingText = workingText.replaceAll(afternoonRegex, ' ');
      }
    }
    if (!hasTime) {
      final eveningRegex = RegExp(r'\b(in\s+the\s+evening|this\s+evening)\b', caseSensitive: false);
      if (eveningRegex.hasMatch(workingText)) {
        resolvedHour = 19;
        resolvedMinute = 0;
        hasTime = true;
        workingText = workingText.replaceAll(eveningRegex, ' ');
      }
    }

    // ── 6. Assemble Final DateTime ──
    DateTime? finalDateTime;
    if (hasDate || hasTime) {
      final datePart = resolvedDate ?? now;
      final h = resolvedHour ?? (hasDate ? now.hour : now.hour);
      final m = resolvedMinute ?? (hasDate ? now.minute : now.minute);
      finalDateTime = DateTime(datePart.year, datePart.month, datePart.day, h, m);
    }

    // ── 7. Clean residual prepositions and spaces ──
    var cleaned = workingText
        .replaceAll(RegExp(r'\b(on|at|for)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*(on|at|for)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return ParsedDateTimeResult(
      dateTime: finalDateTime,
      cleanedText: cleaned,
      hasDate: hasDate,
      hasTime: hasTime,
    );
  }
}
