import 'package:hive/hive.dart';

import '../models/settlement_model.dart';

class SettlementLocalDatasource {
  static const String boxName = 'settlements';

  Box<SettlementModel> get _box => Hive.box<SettlementModel>(boxName);

  List<SettlementModel> getAllSettlements() {
    return _box.values.toList(growable: false);
  }

  Future<void> saveSettlement(SettlementModel settlement) async {
    await _box.put(settlement.id, settlement);
  }

  Future<void> deleteSettlement(String id) async {
    await _box.delete(id);
  }

  List<SettlementModel> getPendingForParticipant(String participantId) {
    return _box.values.where((s) {
      return !s.isSettled &&
          (s.fromParticipantId == participantId ||
              s.toParticipantId == participantId);
    }).toList();
  }

  List<SettlementModel> getSettledForParticipant(String participantId) {
    return _box.values.where((s) {
      return s.isSettled &&
          (s.fromParticipantId == participantId ||
              s.toParticipantId == participantId);
    }).toList();
  }

  List<SettlementModel> getPendingSettlements() {
    return _box.values.where((s) => !s.isSettled).toList();
  }
}
