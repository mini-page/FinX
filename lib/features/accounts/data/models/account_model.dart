import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class AccountModel {
  AccountModel({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.balance,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Account id cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Account name cannot be empty.');
    }
  }

  factory AccountModel.create({
    required String name,
    required String iconKey,
    required double balance,
  }) {
    return AccountModel(
      id: const Uuid().v4(),
      name: name.trim(),
      iconKey: iconKey,
      balance: balance,
    );
  }

  final String id;
  final String name;
  final String iconKey;
  final double balance;

  AccountModel copyWith({
    String? id,
    String? name,
    String? iconKey,
    double? balance,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      balance: balance ?? this.balance,
    );
  }
}

class AccountModelAdapter extends TypeAdapter<AccountModel> {
  static const int typeIdValue = 2;

  @override
  final int typeId = typeIdValue;

  @override
  AccountModel read(BinaryReader reader) {
    return AccountModel(
      id: reader.readString(),
      name: reader.readString(),
      iconKey: reader.readString(),
      balance: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, AccountModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.iconKey)
      ..writeDouble(obj.balance);
  }
}
