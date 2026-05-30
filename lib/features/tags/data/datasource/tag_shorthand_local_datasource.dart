import 'package:hive/hive.dart';
import '../models/tag_shorthand_model.dart';

class TagShorthandLocalDatasource {
  static const String boxName = 'tag_shorthands';

  final Box<TagShorthandModel> _box;

  TagShorthandLocalDatasource(this._box);

  List<TagShorthandModel> getTags() {
    return _box.values.toList();
  }

  Future<void> saveTag(TagShorthandModel tag) async {
    await _box.put(tag.id, tag);
  }

  Future<void> deleteTag(String id) async {
    await _box.delete(id);
  }
}
