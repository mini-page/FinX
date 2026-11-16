import 'package:flutter_test/flutter_test.dart';
import 'package:expensio/core/utils/date_time_parser.dart';

void main() {
  group('DateTimeParser', () {
    final reference = DateTime(2026, 11, 4, 14, 30); // Wednesday, 4 Nov 2026

    test('parses "today" relative date', () {
      final res = DateTimeParser.parse('Spent 200 on lunch today', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.dateTime?.year, 2026);
      expect(res.dateTime?.month, 11);
      expect(res.dateTime?.day, 4);
      expect(res.cleanedText, 'Spent 200 on lunch');
    });

    test('parses "yesterday" relative date', () {
      final res = DateTimeParser.parse('Dinner 500 yesterday', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.dateTime?.year, 2026);
      expect(res.dateTime?.month, 11);
      expect(res.dateTime?.day, 3);
      expect(res.cleanedText, 'Dinner 500');
    });

    test('parses "day before yesterday"', () {
      final res = DateTimeParser.parse('Petrol 1000 day before yesterday', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.dateTime?.year, 2026);
      expect(res.dateTime?.month, 11);
      expect(res.dateTime?.day, 2);
      expect(res.cleanedText, 'Petrol 1000');
    });

    test('parses explicit time "at 4pm" and 12-hour am/pm', () {
      final res = DateTimeParser.parse('Coffee 120 at 4pm', referenceNow: reference);
      expect(res.hasTime, isTrue);
      expect(res.dateTime?.hour, 16);
      expect(res.dateTime?.minute, 0);
      expect(res.cleanedText, 'Coffee 120');
    });

    test('parses time with minutes "10:30 am"', () {
      final res = DateTimeParser.parse('Breakfast 150 at 10:30 am', referenceNow: reference);
      expect(res.hasTime, isTrue);
      expect(res.dateTime?.hour, 10);
      expect(res.dateTime?.minute, 30);
      expect(res.cleanedText, 'Breakfast 150');
    });

    test('parses combined date and time "yesterday at 8:15 pm"', () {
      final res = DateTimeParser.parse('Groceries 850 yesterday at 8:15 pm', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.hasTime, isTrue);
      expect(res.dateTime?.year, 2026);
      expect(res.dateTime?.month, 11);
      expect(res.dateTime?.day, 3);
      expect(res.dateTime?.hour, 20);
      expect(res.dateTime?.minute, 15);
      expect(res.cleanedText, 'Groceries 850');
    });

    test('parses explicit calendar date "15th oct" and "15 october 2026"', () {
      final res = DateTimeParser.parse('Hotel 3500 on 15th oct', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.dateTime?.month, 10);
      expect(res.dateTime?.day, 15);
      expect(res.cleanedText, 'Hotel 3500');
    });

    test('parses weekday "last sunday"', () {
      final res = DateTimeParser.parse('Party 1200 last sunday', referenceNow: reference);
      expect(res.hasDate, isTrue);
      expect(res.dateTime?.weekday, DateTime.sunday);
      expect(res.cleanedText, 'Party 1200');
    });
  });
}
