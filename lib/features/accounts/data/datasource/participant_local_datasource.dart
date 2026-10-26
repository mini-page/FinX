import 'package:hive/hive.dart';

import '../models/participant_model.dart';

class ParticipantLocalDatasource {
  static const String boxName = 'participants';

  Box<ParticipantModel> get _box => Hive.box<ParticipantModel>(boxName);

  Future<List<ParticipantModel>> getAllParticipants() async {
    final list = _box.values.toList(growable: false)
      ..sort((left, right) => left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    return list;
  }

  Future<void> saveParticipant(ParticipantModel participant) async {
    await _box.put(participant.id, participant);
  }

  Future<void> saveParticipants(List<ParticipantModel> list) async {
    final entries = {for (final p in list) p.id: p};
    await _box.putAll(entries);
  }

  Future<void> deleteParticipant(String id) async {
    await _box.delete(id);
  }
}
