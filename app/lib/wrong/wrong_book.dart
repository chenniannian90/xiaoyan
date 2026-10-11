import 'dart:convert';

import 'package:hive/hive.dart';

/// 错题本里的一道题:哪个包、第几题、错了多少次。
///
/// 注意存的是「曾经错过」而不是「现在还不会」 —— 做对一次就从未知变已知?
/// v1 的口径:**错过就留档**,重练做对时把 `resolvedAt` 盖上,列表里划掉但可翻看。
/// 这是给大人看的素材来源(下一轮出什么内容),不是给孩子的红叉榜。
class WrongAnswer {
  const WrongAnswer({
    required this.slug,
    required this.itemIndex,
    required this.topicTitle,
    required this.prompt,
    required this.wrongCount,
    required this.lastAt,
    this.resolvedAt,
  });

  final String slug;

  /// 第几题(practice.items 的下标,从 0 数)。
  final int itemIndex;

  /// 展示用:哪节课的题。
  final String topicTitle;

  /// 展示用:题干原文。重练入口直接显示它,不用再去解析内容包。
  final String prompt;

  /// 累计错了几次。
  final int wrongCount;

  /// 最近一次错是什么时候。
  final DateTime lastAt;

  /// 重练做对的时间。null = 还没翻过身。
  final DateTime? resolvedAt;

  bool get resolved => resolvedAt != null;

  /// 同一道题的唯一键:包 + 下标。
  String get key => '$slug:$itemIndex';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'slug': slug,
        'itemIndex': itemIndex,
        'topicTitle': topicTitle,
        'prompt': prompt,
        'wrongCount': wrongCount,
        'lastAt': lastAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  static WrongAnswer fromJson(Map<String, dynamic> json) => WrongAnswer(
        slug: json['slug'] as String,
        itemIndex: json['itemIndex'] as int,
        topicTitle: json['topicTitle'] as String,
        prompt: json['prompt'] as String,
        wrongCount: json['wrongCount'] as int,
        lastAt: DateTime.parse(json['lastAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String),
      );

  WrongAnswer copyWith({
    int? wrongCount,
    DateTime? lastAt,
    DateTime? resolvedAt,
  }) =>
      WrongAnswer(
        slug: slug,
        itemIndex: itemIndex,
        topicTitle: topicTitle,
        prompt: prompt,
        wrongCount: wrongCount ?? this.wrongCount,
        lastAt: lastAt ?? this.lastAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );
}

/// 错题本的存放处。接口跟实验册([JournalStore] 同款)对齐:
/// Hive 实现 + 内存实现,App 里 Hive 起不来时退内存,不让练习页崩。
abstract class WrongBookStore {
  /// 未翻身的在前(重练先做这些),同组里最近错的在前。
  Future<List<WrongAnswer>> all();

  /// 记一次错:没有就建档,有就把 wrongCount + 1。
  Future<void> recordWrong(WrongAnswer entry);

  /// 这道题重练做对了:盖上 resolvedAt。没记过的题调它等于没发生。
  Future<void> resolve(String slug, int itemIndex);

  Future<void> remove(String key);
}

class HiveWrongBookStore implements WrongBookStore {
  HiveWrongBookStore({this.boxName = 'wrong-answers'});

  final String boxName;

  Future<Box<String>> get _box async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  @override
  Future<List<WrongAnswer>> all() async {
    final Box<String> box = await _box;
    final List<WrongAnswer> entries = box.values
        .map((String raw) => _tryDecode(raw))
        .whereType<WrongAnswer>()
        .toList();
    entries.sort((WrongAnswer a, WrongAnswer b) {
      if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
      return b.lastAt.compareTo(a.lastAt);
    });
    return entries;
  }

  @override
  Future<void> recordWrong(WrongAnswer entry) async {
    final Box<String> box = await _box;
    final WrongAnswer? old = _tryDecode(box.get(entry.key));
    // entry 是这次刚错的(resolvedAt 本来就是 null),所以旧的档不管翻没翻过身,
    // 这次错完都得回到「没翻身」。copyWith 只加次数,不碰 resolvedAt。
    await box.put(
      entry.key,
      _encode(old == null ? entry : entry.copyWith(wrongCount: old.wrongCount + 1)),
    );
  }

  @override
  Future<void> resolve(String slug, int itemIndex) async {
    final Box<String> box = await _box;
    final String key = '$slug:$itemIndex';
    final WrongAnswer? old = _tryDecode(box.get(key));
    if (old == null) return;
    await box.put(key, _encode(old.copyWith(resolvedAt: DateTime.now())));
  }

  @override
  Future<void> remove(String key) async {
    final Box<String> box = await _box;
    await box.delete(key);
  }

  static String _encode(WrongAnswer e) => jsonEncode(e.toJson());

  static WrongAnswer? _tryDecode(String? raw) => raw == null
      ? null
      : WrongAnswer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// 内存实现:测试用,也是 Hive 起不来时的兜底。
class MemoryWrongBookStore implements WrongBookStore {
  final Map<String, WrongAnswer> _entries = <String, WrongAnswer>{};

  @override
  Future<List<WrongAnswer>> all() async {
    final List<WrongAnswer> list = _entries.values.toList();
    list.sort((WrongAnswer a, WrongAnswer b) {
      if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
      return b.lastAt.compareTo(a.lastAt);
    });
    return list;
  }

  @override
  Future<void> recordWrong(WrongAnswer entry) async {
    final WrongAnswer? old = _entries[entry.key];
    _entries[entry.key] = old == null
        ? entry
        : entry.copyWith(wrongCount: old.wrongCount + 1);
  }

  @override
  Future<void> resolve(String slug, int itemIndex) async {
    final WrongAnswer? old = _entries['$slug:$itemIndex'];
    if (old == null) return;
    _entries[old.key] = old.copyWith(resolvedAt: DateTime.now());
  }

  @override
  Future<void> remove(String key) async => _entries.remove(key);
}
