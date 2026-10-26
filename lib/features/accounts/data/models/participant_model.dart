import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class ParticipantModel {
  ParticipantModel({
    required this.id,
    required this.name,
    this.nickname,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Participant id cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Participant name cannot be empty.');
    }
  }

  factory ParticipantModel.create({
    required String name,
    String? nickname,
  }) {
    return ParticipantModel(
      id: const Uuid().v4(),
      name: name.trim(),
      nickname: nickname?.trim().isEmpty ?? true ? null : nickname?.trim(),
    );
  }

  final String id;
  final String name;
  final String? nickname;

  ParticipantModel copyWith({
    String? id,
    String? name,
    String? nickname,
    bool clearNickname = false,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: clearNickname ? null : nickname ?? this.nickname,
    );
  }
}

class ParticipantModelAdapter extends TypeAdapter<ParticipantModel> {
  static const int typeIdValue = 6;

  @override
  final int typeId = typeIdValue;

  @override
  ParticipantModel read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final nickname = reader.readString();
    return ParticipantModel(
      id: id,
      name: name,
      nickname: nickname.isEmpty ? null : nickname,
    );
  }

  @override
  void write(BinaryWriter writer, ParticipantModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.nickname ?? '');
  }
}
