import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class SettlementModel {
  SettlementModel({
    required this.id,
    required this.fromParticipantId,
    required this.fromParticipantName,
    required this.toParticipantId,
    required this.toParticipantName,
    required this.amount,
    this.expenseId,
    this.expenseDescription,
    required this.createdAt,
    this.settledAt,
    this.note,
  });

  factory SettlementModel.create({
    required String fromParticipantId,
    required String fromParticipantName,
    required String toParticipantId,
    required String toParticipantName,
    required double amount,
    String? expenseId,
    String? expenseDescription,
    String? note,
  }) {
    return SettlementModel(
      id: const Uuid().v4(),
      fromParticipantId: fromParticipantId,
      fromParticipantName: fromParticipantName,
      toParticipantId: toParticipantId,
      toParticipantName: toParticipantName,
      amount: amount,
      expenseId: expenseId,
      expenseDescription: expenseDescription,
      createdAt: DateTime.now(),
      settledAt: null,
      note: note,
    );
  }

  final String id;
  final String fromParticipantId;
  final String fromParticipantName;
  final String toParticipantId;
  final String toParticipantName;
  final double amount;
  final String? expenseId;
  final String? expenseDescription;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? note;

  bool get isSettled => settledAt != null;

  SettlementModel copyWith({
    String? id,
    String? fromParticipantId,
    String? fromParticipantName,
    String? toParticipantId,
    String? toParticipantName,
    double? amount,
    String? expenseId,
    String? expenseDescription,
    DateTime? createdAt,
    DateTime? settledAt,
    bool? clearSettledAt,
    String? note,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      fromParticipantId: fromParticipantId ?? this.fromParticipantId,
      fromParticipantName: fromParticipantName ?? this.fromParticipantName,
      toParticipantId: toParticipantId ?? this.toParticipantId,
      toParticipantName: toParticipantName ?? this.toParticipantName,
      amount: amount ?? this.amount,
      expenseId: expenseId ?? this.expenseId,
      expenseDescription: expenseDescription ?? this.expenseDescription,
      createdAt: createdAt ?? this.createdAt,
      settledAt: clearSettledAt == true ? null : (settledAt ?? this.settledAt),
      note: note ?? this.note,
    );
  }

  SettlementModel markSettled() => copyWith(settledAt: DateTime.now());

  ParticipantDebtSummary toDebtSummary() {
    return ParticipantDebtSummary(
      participantId: fromParticipantId,
      participantName: fromParticipantName,
      netBalance: -amount,
      pendingCount: isSettled ? 0 : 1,
    );
  }
}

class ParticipantDebtSummary {
  const ParticipantDebtSummary({
    required this.participantId,
    required this.participantName,
    required this.netBalance,
    this.pendingCount = 0,
  });

  final String participantId;
  final String participantName;
  final double netBalance;
  final int pendingCount;
}

class SettlementModelAdapter extends TypeAdapter<SettlementModel> {
  static const int typeIdValue = 7;

  @override
  final int typeId = typeIdValue;

  @override
  SettlementModel read(BinaryReader reader) {
    final id = reader.readString();
    final fromId = reader.readString();
    final fromName = reader.readString();
    final toId = reader.readString();
    final toName = reader.readString();
    final amount = reader.readDouble();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    String? expenseId;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) expenseId = s;
    } catch (_) {}

    String? expenseDesc;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) expenseDesc = s;
    } catch (_) {}

    DateTime? settledAt;
    try {
      final ts = reader.readInt();
      if (ts != 0) settledAt = DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (_) {}

    String? note;
    try {
      final s = reader.readString();
      if (s.isNotEmpty) note = s;
    } catch (_) {}

    return SettlementModel(
      id: id,
      fromParticipantId: fromId,
      fromParticipantName: fromName,
      toParticipantId: toId,
      toParticipantName: toName,
      amount: amount,
      expenseId: expenseId,
      expenseDescription: expenseDesc,
      createdAt: createdAt,
      settledAt: settledAt,
      note: note,
    );
  }

  @override
  void write(BinaryWriter writer, SettlementModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.fromParticipantId)
      ..writeString(obj.fromParticipantName)
      ..writeString(obj.toParticipantId)
      ..writeString(obj.toParticipantName)
      ..writeDouble(obj.amount)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeString(obj.expenseId ?? '')
      ..writeString(obj.expenseDescription ?? '')
      ..writeInt(obj.settledAt?.millisecondsSinceEpoch ?? 0)
      ..writeString(obj.note ?? '');
  }
}
