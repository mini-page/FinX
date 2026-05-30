import 'package:hive/hive.dart';

class TagShorthandModel {
  TagShorthandModel({
    required this.id,
    required this.name,
    this.amount,
    this.accountId,
    this.categoryName,
    this.subcategoryName,
    this.note,
  });

  final String id;
  final String name;
  final double? amount;
  final String? accountId;
  final String? categoryName;
  final String? subcategoryName;
  final String? note;

  TagShorthandModel copyWith({
    String? name,
    double? amount,
    bool clearAmount = false,
    String? accountId,
    bool clearAccountId = false,
    String? categoryName,
    bool clearCategoryName = false,
    String? subcategoryName,
    bool clearSubcategoryName = false,
    String? note,
    bool clearNote = false,
  }) {
    return TagShorthandModel(
      id: id,
      name: name ?? this.name,
      amount: clearAmount ? null : amount ?? this.amount,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      categoryName: clearCategoryName ? null : categoryName ?? this.categoryName,
      subcategoryName: clearSubcategoryName ? null : subcategoryName ?? this.subcategoryName,
      note: clearNote ? null : note ?? this.note,
    );
  }
}

class TagShorthandModelAdapter extends TypeAdapter<TagShorthandModel> {
  static const int typeIdValue = 5;

  @override
  final int typeId = typeIdValue;

  @override
  TagShorthandModel read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();

    double? amount;
    if (reader.readBool()) {
      amount = reader.readDouble();
    }

    String? accountId;
    if (reader.readBool()) {
      accountId = reader.readString();
    }

    String? categoryName;
    if (reader.readBool()) {
      categoryName = reader.readString();
    }

    String? subcategoryName;
    if (reader.readBool()) {
      subcategoryName = reader.readString();
    }

    String? note;
    if (reader.readBool()) {
      note = reader.readString();
    }

    return TagShorthandModel(
      id: id,
      name: name,
      amount: amount,
      accountId: accountId,
      categoryName: categoryName,
      subcategoryName: subcategoryName,
      note: note,
    );
  }

  @override
  void write(BinaryWriter writer, TagShorthandModel obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);

    writer.writeBool(obj.amount != null);
    if (obj.amount != null) {
      writer.writeDouble(obj.amount!);
    }

    writer.writeBool(obj.accountId != null);
    if (obj.accountId != null) {
      writer.writeString(obj.accountId!);
    }

    writer.writeBool(obj.categoryName != null);
    if (obj.categoryName != null) {
      writer.writeString(obj.categoryName!);
    }

    writer.writeBool(obj.subcategoryName != null);
    if (obj.subcategoryName != null) {
      writer.writeString(obj.subcategoryName!);
    }

    writer.writeBool(obj.note != null);
    if (obj.note != null) {
      writer.writeString(obj.note!);
    }
  }
}
