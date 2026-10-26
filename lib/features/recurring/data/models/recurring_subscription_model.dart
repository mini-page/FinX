import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../domain/recurrence_parser.dart';

enum SubscriptionStatus { active, expired, cancelled }

class RecurringSubscriptionModel {
  RecurringSubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    required DateTime nextBillDate,
    required this.iconKey,
    this.note = '',
    this.isActive = true,
    this.billingPeriod = '1:month',
    this.category = '',
    this.lastPaymentDate,
    this.priceHistory = const [],
    this.notifyDaysBefore = 7,
    this.cancellationNote,
    this.cancelledAt,
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
    String billingPeriod = '1:month',
    String category = '',
    DateTime? lastPaymentDate,
    List<double> priceHistory = const [],
    int notifyDaysBefore = 7,
    String? cancellationNote,
    DateTime? cancelledAt,
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
      category: category,
      lastPaymentDate: lastPaymentDate,
      priceHistory: priceHistory,
      notifyDaysBefore: notifyDaysBefore,
      cancellationNote: cancellationNote,
      cancelledAt: cancelledAt,
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
  final String category;

  // ── New fields ──────────────────────────────────────────────────────────────

  /// When the last payment was logged.
  final DateTime? lastPaymentDate;

  /// Historical amounts for price increase detection (most recent first).
  final List<double> priceHistory;

  /// How many days before billing to show a pre-billing notification.
  final int notifyDaysBefore;

  /// Optional note explaining why the subscription was cancelled.
  final String? cancellationNote;

  /// When the subscription was cancelled (set when isActive → false manually).
  final DateTime? cancelledAt;

  // ── Computed ────────────────────────────────────────────────────────────────

  RecurrenceParsed get recurrence => decodeRecurrence(billingPeriod);

  int get daysUntilBilling =>
      DateTime.now().difference(nextBillDate).inDays < 0
          ? nextBillDate.difference(DateTime.now()).inDays
          : -DateTime.now().difference(nextBillDate).inDays;

  bool get isPastDue => nextBillDate.isBefore(DateTime.now()) && isActive;

  /// True if nextBillDate is past and no payment logged for 2+ billing cycles.
  bool get isExpired {
    if (!isActive || lastPaymentDate == null) return false;
    final rec = recurrence;
    DateTime threshold;
    switch (rec.unit) {
      case RecurrenceUnit.day:
        threshold = DateTime.now().subtract(Duration(days: rec.count * 2));
      case RecurrenceUnit.week:
        threshold = DateTime.now().subtract(Duration(days: rec.count * 14));
      case RecurrenceUnit.month:
        threshold = DateTime.now().subtract(Duration(days: rec.count * 60));
    }
    return lastPaymentDate!.isBefore(threshold);
  }

  /// Whether the latest amount differs from the average of previous prices.
  bool get isPriceIncreased {
    if (priceHistory.length < 2) return false;
    final avg = priceHistory.sublist(1).reduce((a, b) => a + b) /
        (priceHistory.length - 1);
    return amount > avg * 1.05; // >5% increase
  }

  double? get previousAmount =>
      priceHistory.isNotEmpty ? priceHistory.first : null;

  // ── Methods ─────────────────────────────────────────────────────────────────

  RecurringSubscriptionModel copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? nextBillDate,
    String? iconKey,
    String? note,
    bool? isActive,
    String? billingPeriod,
    String? category,
    DateTime? lastPaymentDate,
    bool? clearLastPaymentDate,
    List<double>? priceHistory,
    int? notifyDaysBefore,
    String? cancellationNote,
    bool? clearCancellationNote,
    DateTime? cancelledAt,
    bool? clearCancelledAt,
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
      category: category ?? this.category,
      lastPaymentDate: clearLastPaymentDate == true
          ? null
          : (lastPaymentDate ?? this.lastPaymentDate),
      priceHistory: priceHistory ?? this.priceHistory,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      cancellationNote: clearCancellationNote == true
          ? null
          : (cancellationNote ?? this.cancellationNote),
      cancelledAt: clearCancelledAt == true
          ? null
          : (cancelledAt ?? this.cancelledAt),
    );
  }

  /// Records a payment: updates lastPaymentDate and tracks amount in priceHistory.
  RecurringSubscriptionModel recordPayment(DateTime paidAt) {
    final updatedHistory = [amount, ...priceHistory].take(12).toList();
    return copyWith(
      lastPaymentDate: paidAt,
      priceHistory: updatedHistory,
    );
  }

  DateTime calculateNextBillDate(DateTime fromDate) {
    return recurrence.nextDate(fromDate);
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

    String billingPeriod = '1:month';
    try {
      billingPeriod = reader.readString();
    } catch (_) {}

    String category = '';
    try {
      category = reader.readString();
    } catch (_) {}

    // ── New fields (backwards compatible) ──────────────────────────────────
    DateTime? lastPaymentDate;
    try {
      final ts = reader.readInt();
      if (ts != 0) lastPaymentDate = DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (_) {}

    List<double> priceHistory = const [];
    try {
      final len = reader.readByte();
      priceHistory = List.generate(len, (_) => reader.readDouble());
    } catch (_) {}

    int notifyDaysBefore = 7;
    try {
      notifyDaysBefore = reader.readInt();
    } catch (_) {}

    String? cancellationNote;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) cancellationNote = s;
    } catch (_) {}

    DateTime? cancelledAt;
    try {
      final ts = reader.readInt();
      if (ts != 0) cancelledAt = DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (_) {}

    return RecurringSubscriptionModel(
      id: id,
      name: name,
      amount: amount,
      nextBillDate: nextBillDate,
      iconKey: iconKey,
      note: note,
      isActive: isActive,
      billingPeriod: billingPeriod,
      category: category,
      lastPaymentDate: lastPaymentDate,
      priceHistory: priceHistory,
      notifyDaysBefore: notifyDaysBefore,
      cancellationNote: cancellationNote,
      cancelledAt: cancelledAt,
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
      ..writeString(obj.billingPeriod)
      ..writeString(obj.category);
    // New fields
    writer.writeInt(obj.lastPaymentDate?.millisecondsSinceEpoch ?? 0);
    writer.writeByte(obj.priceHistory.length);
    for (final d in obj.priceHistory) {
      writer.writeDouble(d);
    }
    writer.writeInt(obj.notifyDaysBefore);
    writer.writeString(obj.cancellationNote ?? '');
    writer.writeInt(obj.cancelledAt?.millisecondsSinceEpoch ?? 0);
  }
}
