import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xiaoyan/journal/journal_entry.dart';
import 'package:xiaoyan/journal/journal_store.dart';

/// 实验册真的存住了没有?
///
/// 这一条能写成"真的读写"而不是"假装读写",全靠 Hive 是**纯 Dart 的键值库、
/// 不走平台通道** —— 它在 `flutter test` 里能开真盒子、写真文件。
/// (换成 shared_preferences 这类走通道的,这里就只能 mock 自己,测了个寂寞。)
JournalEntry _entry(String id, DateTime at, {int step = 0, String? photo}) => JournalEntry(
      id: id,
      slug: 'salt-water-egg',
      title: '盐水浮鸡蛋',
      stepIndex: step,
      stepText: '看一看,鸡蛋在哪儿呀?',
      optionId: 'sunk',
      optionLabel: '沉在杯底了',
      photoPath: photo,
      at: at,
    );

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('xiaoyan-journal');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('存进去再读出来,一笔的每个字段都还在', () async {
    final HiveJournalStore store = HiveJournalStore(boxName: 'roundtrip');
    final DateTime at = DateTime(2026, 10, 11, 10, 30);
    await store.add(_entry('a1', at, step: 2, photo: 'photos/1712.jpg'));

    final List<JournalEntry> got = await store.all();
    expect(got, hasLength(1));
    expect(got.single.id, 'a1');
    expect(got.single.title, '盐水浮鸡蛋');
    expect(got.single.stepIndex, 2);
    expect(got.single.stepText, '看一看,鸡蛋在哪儿呀?');
    expect(got.single.optionId, 'sunk');
    expect(got.single.optionLabel, '沉在杯底了');
    expect(got.single.photoPath, 'photos/1712.jpg');
    expect(got.single.at, at, reason: '时间要精确到秒,别在序列化里丢精度');
  });

  test('读出来新的在前', () async {
    final HiveJournalStore store = HiveJournalStore(boxName: 'order');
    await store.add(_entry('old', DateTime(2026, 10, 10, 9)));
    await store.add(_entry('new', DateTime(2026, 10, 11, 9)));
    await store.add(_entry('mid', DateTime(2026, 10, 10, 20)));

    final List<JournalEntry> got = await store.all();
    expect(got.map((JournalEntry e) => e.id).toList(), <String>['new', 'mid', 'old']);
  });

  test('删了就真没了', () async {
    final HiveJournalStore store = HiveJournalStore(boxName: 'delete');
    await store.add(_entry('keep', DateTime(2026, 10, 11, 8)));
    await store.add(_entry('drop', DateTime(2026, 10, 11, 9)));

    await store.remove('drop');
    expect((await store.all()).map((JournalEntry e) => e.id), <String>['keep']);

    // 删不存在的也不该炸(界面上划得快,重复删是可能的)
    await store.remove('drop');
    expect(await store.all(), hasLength(1));
  });

  test('关掉盒子再开,记录还在 —— 不是只活在内存里', () async {
    final HiveJournalStore store = HiveJournalStore(boxName: 'persist');
    await store.add(_entry('written', DateTime(2026, 10, 11, 7)));

    // 把盒子关掉:内存里那份没了,只剩盘上的文件
    await Hive.box<String>('persist').close();
    expect(Hive.isBoxOpen('persist'), isFalse);

    final HiveJournalStore reopened = HiveJournalStore(boxName: 'persist');
    final List<JournalEntry> got = await reopened.all();
    expect(got, hasLength(1));
    expect(got.single.id, 'written');
    expect(got.single.optionLabel, '沉在杯底了', reason: '重新打开还是原来那一笔,说明写的是盘不是内存');
  });

  test('内存实现跟 Hive 实现的表现一致(界面测试用的就是它)', () async {
    final MemoryJournalStore store = MemoryJournalStore();
    await store.add(_entry('old', DateTime(2026, 10, 10, 9)));
    await store.add(_entry('new', DateTime(2026, 10, 11, 9)));

    expect((await store.all()).map((JournalEntry e) => e.id), <String>['new', 'old']);
    await store.remove('new');
    expect((await store.all()).map((JournalEntry e) => e.id), <String>['old']);
  });
}
