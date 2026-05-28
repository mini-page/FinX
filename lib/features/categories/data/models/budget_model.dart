import 'package:hive/hive.dart';

class BudgetModel {
  BudgetModel({required this.category, required this.monthlyLimit}) {
    if (category.trim().isEmpty) {
      throw ArgumentError.value(
        category,
        'category',
        'Budget category cannot be empty.',
      );
    }
    if (monthlyLimit < 0) {
      throw ArgumentError.value(
        monthlyLimit,
        'monthlyLimit',
        'Budget amount cannot be negative.',
      );
    }
  }

  final String category;
  final double monthlyLimit;
}

class BudgetModelAdapter extends TypeAdapter<BudgetModel> {
  static const int typeIdValue = 1;

  @override
  final int typeId = typeIdValue;

  @override
  BudgetModel read(BinaryReader reader) {
    return BudgetModel(
      category: reader.readString(),
      monthlyLimit: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, BudgetModel obj) {
    writer
      ..writeString(obj.category)
      ..writeDouble(obj.monthlyLimit);
  }
}
