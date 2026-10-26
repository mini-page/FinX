import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasource/participant_local_datasource.dart';
import '../../data/models/participant_model.dart';

final participantLocalDatasourceProvider = Provider<ParticipantLocalDatasource>((ref) {
  return ParticipantLocalDatasource();
});

final participantListProvider =
    AsyncNotifierProvider<ParticipantListNotifier, List<ParticipantModel>>(
  ParticipantListNotifier.new,
);

class ParticipantListNotifier extends AsyncNotifier<List<ParticipantModel>> {
  ParticipantLocalDatasource get _datasource =>
      ref.read(participantLocalDatasourceProvider);

  @override
  Future<List<ParticipantModel>> build() async {
    return _datasource.getAllParticipants();
  }

  Future<void> saveParticipant(ParticipantModel participant) async {
    final current = state.value ?? const <ParticipantModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.saveParticipant(participant);
      final list = [
        for (final item in current)
          if (item.id != participant.id) item,
        participant,
      ]..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));
      return list;
    });
  }

  Future<void> deleteParticipant(String id) async {
    final current = state.value ?? const <ParticipantModel>[];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.deleteParticipant(id);
      return current.where((p) => p.id != id).toList();
    });
  }
}
