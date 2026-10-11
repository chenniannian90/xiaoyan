import 'package:hive/hive.dart';

import 'journal_entry.dart';

/// 实验册的存放处。
///
/// 抽象出来有两个理由:一是界面测试里不该真去开一个盒子(还得准备目录);
/// 二是"存哪儿"以后可能换(比如以后要同步),换的时候界面一行都不用动。
abstract class JournalStore {
  /// 按时间倒序 —— 最新记的那笔排最前面。
  Future<List<JournalEntry>> all();

  Future<void> add(JournalEntry entry);

  Future<void> remove(String id);
}

/// Hive 实现:一个盒子,一笔一条 JSON 字符串。
///
/// 选 Hive 不光因为它已经在依赖里 —— 它是**纯 Dart 的键值库,不走平台通道**,
/// 所以在 `flutter test` 里照样能开盒读写,"存进去再读出来"这件事能被真的测到。
/// (调用方负责 `Hive.init` / `Hive.initFlutter`,这里只管开盒。)
class HiveJournalStore implements JournalStore {
  HiveJournalStore({this.boxName = 'journal'});

  final String boxName;

  Future<Box<String>> get _box async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  @override
  Future<List<JournalEntry>> all() async {
    final Box<String> box = await _box;
    final List<JournalEntry> entries = box.values.map(JournalEntry.decode).toList();
    entries.sort((JournalEntry a, JournalEntry b) => b.at.compareTo(a.at));
    return entries;
  }

  @override
  Future<void> add(JournalEntry entry) async {
    final Box<String> box = await _box;
    await box.put(entry.id, entry.encode());
  }

  @override
  Future<void> remove(String id) async {
    final Box<String> box = await _box;
    await box.delete(id);
  }
}

/// 内存实现。测试用;也给"Hive 起不来"的情况兜底(App 不该因为存不了就崩)。
class MemoryJournalStore implements JournalStore {
  final List<JournalEntry> _entries = <JournalEntry>[];

  @override
  Future<List<JournalEntry>> all() async {
    final List<JournalEntry> copy = List<JournalEntry>.of(_entries);
    copy.sort((JournalEntry a, JournalEntry b) => b.at.compareTo(a.at));
    return copy;
  }

  @override
  Future<void> add(JournalEntry entry) async => _entries.add(entry);

  @override
  Future<void> remove(String id) async =>
      _entries.removeWhere((JournalEntry e) => e.id == id);
}
