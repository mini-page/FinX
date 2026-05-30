import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasource/tag_shorthand_local_datasource.dart';
import '../../data/models/tag_shorthand_model.dart';

final tagShorthandBoxProvider = Provider<Box<TagShorthandModel>>((ref) {
  return Hive.box<TagShorthandModel>(TagShorthandLocalDatasource.boxName);
});

final tagShorthandDatasourceProvider = Provider<TagShorthandLocalDatasource>((ref) {
  final box = ref.watch(tagShorthandBoxProvider);
  return TagShorthandLocalDatasource(box);
});

class TagShorthandController extends Notifier<List<TagShorthandModel>> {
  @override
  List<TagShorthandModel> build() {
    final datasource = ref.watch(tagShorthandDatasourceProvider);
    return datasource.getTags();
  }

  void _loadTags() {
    final datasource = ref.read(tagShorthandDatasourceProvider);
    state = datasource.getTags();
  }

  Future<void> addTag({
    required String name,
    double? amount,
    String? accountId,
    String? categoryName,
    String? subcategoryName,
    String? note,
  }) async {
    final cleanName = name.replaceAll('#', '').trim();
    if (cleanName.isEmpty) return;

    final id = const Uuid().v4();
    final tag = TagShorthandModel(
      id: id,
      name: cleanName,
      amount: amount,
      accountId: accountId,
      categoryName: categoryName,
      subcategoryName: subcategoryName,
      note: note,
    );
    final datasource = ref.read(tagShorthandDatasourceProvider);
    await datasource.saveTag(tag);
    _loadTags();
  }

  Future<void> updateTag(TagShorthandModel tag) async {
    final datasource = ref.read(tagShorthandDatasourceProvider);
    await datasource.saveTag(tag);
    _loadTags();
  }

  Future<void> deleteTag(String id) async {
    final datasource = ref.read(tagShorthandDatasourceProvider);
    await datasource.deleteTag(id);
    _loadTags();
  }
}

final tagShorthandControllerProvider = NotifierProvider<TagShorthandController, List<TagShorthandModel>>(TagShorthandController.new);
