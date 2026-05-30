import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class RecurringSubscriptionModel {
  RecurringSubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    required DateTime nextBillDate,
    required this.iconKey,
    this.note = '',
    this.isActive = true,
    this.billingPeriod = 'monthly',
  }) : nextBillDate = DateTime(
          nextBillDate.year,
          nextBillDate.month,
          nextBillDate.day,
        ) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Subscription id cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Subscription name cannot be empty.',
      );
    }
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Subscription amount must be positive.',
      );
    }
  }

  factory RecurringSubscriptionModel.create({
    required String name,
    required double amount,
    required DateTime nextBillDate,
    required String iconKey,
    String note = '',
    bool isActive = true,
    String billingPeriod = 'monthly',
  }) {
    return RecurringSubscriptionModel(
      id: const Uuid().v4(),
      name: name.trim(),
      amount: amount,
      nextBillDate: nextBillDate,
      iconKey: iconKey,
      note: note.trim(),
      isActive: isActive,
      billingPeriod: billingPeriod,
    );
  }

  final String id;
  final String name;
  final double amount;
  final DateTime nextBillDate;
  final String iconKey;
  final String note;
  final bool isActive;
  final String billingPeriod;

  RecurringSubscriptionModel copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? nextBillDate,
    String? iconKey,
    String? note,
    bool? isActive,
    String? billingPeriod,
  }) {
    return RecurringSubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      nextBillDate: nextBillDate ?? this.nextBillDate,
      iconKey: iconKey ?? this.iconKey,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      billingPeriod: billingPeriod ?? this.billingPeriod,
    );
  }

  DateTime calculateNextBillDate(DateTime fromDate) {
    switch (billingPeriod.toLowerCase()) {
      case 'weekly':
        return fromDate.add(const Duration(days: 7));
      case 'quarterly':
        int nextMonth = fromDate.month + 3;
        int nextYear = fromDate.year;
        if (nextMonth > 12) {
          nextYear += (nextMonth - 1) ~/ 12;
          nextMonth = (nextMonth - 1) % 12 + 1;
        }
        int daysInNextMonth = _getDaysInMonth(nextYear, nextMonth);
        return DateTime(nextYear, nextMonth, fromDate.day.clamp(1, daysInNextMonth));
      case 'yearly':
        int nextYear = fromDate.year + 1;
        int nextMonth = fromDate.month;
        int daysInNextMonth = _getDaysInMonth(nextYear, nextMonth);
        return DateTime(nextYear, nextMonth, fromDate.day.clamp(1, daysInNextMonth));
      case 'monthly':
      default:
        int nextMonth = fromDate.month + 1;
        int nextYear = fromDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        int daysInNextMonth = _getDaysInMonth(nextYear, nextMonth);
        return DateTime(nextYear, nextMonth, fromDate.day.clamp(1, daysInNextMonth));
    }
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }
}


class RecurringSubscriptionModelAdapter
    extends TypeAdapter<RecurringSubscriptionModel> {
  static const int typeIdValue = 4;

  @override
  final int typeId = typeIdValue;

  @override
  RecurringSubscriptionModel read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final amount = reader.readDouble();
    final nextBillDate = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final iconKey = reader.readString();
    final note = reader.readString();
    final isActive = reader.readBool();

    String billingPeriod = 'monthly';
    try {
      billingPeriod = reader.readString();
    } catch (_) {
      billingPeriod = 'monthly';
    }

    return RecurringSubscriptionModel(
      id: id,
      name: name,
      amount: amount,
      nextBillDate: nextBillDate,
      iconKey: iconKey,
      note: note,
      isActive: isActive,
      billingPeriod: billingPeriod,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringSubscriptionModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeDouble(obj.amount)
      ..writeInt(obj.nextBillDate.millisecondsSinceEpoch)
      ..writeString(obj.iconKey)
      ..writeString(obj.note)
      ..writeBool(obj.isActive)
      ..writeString(obj.billingPeriod);
  }
}
