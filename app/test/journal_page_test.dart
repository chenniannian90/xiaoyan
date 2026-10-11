import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/journal/journal_entry.dart';
import 'package:xiaoyan/journal/journal_scope.dart';
import 'package:xiaoyan/journal/journal_store.dart';
import 'package:xiaoyan/media/photo_taker.dart';
import 'package:xiaoyan/shell/journal_page.dart';

import 'support/screenshot_fonts.dart';

/// 实验册那一页:空的时候说清楚怎么才会有,有记录的时候按新的在上摆着。
///
/// 照片是真的去磁盘上找的(`AppPaths.resolve` + `File.existsSync`),所以这几条
/// 把 `AppPaths.documentsDir` 指到一个临时目录里,自己造文件。
/// 注意:临时目录是**进程内全局**的,但每个测试文件跑在自己的 isolate 里,不会串台。
///
/// 1×1 的真 PNG(不是随便一段字节 —— Image.file 拿到坏数据会报错)。
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

JournalEntry entry(
  String id,
  DateTime at, {
  int step = 2,
  String optionId = 'sunk',
  String optionLabel = '沉在杯底了',
  String? photo,
}) =>
    JournalEntry(
      id: id,
      slug: 'salt-water-egg',
      title: '盐水浮鸡蛋',
      stepIndex: step,
      stepText: '看一看,鸡蛋在哪儿呀?',
      optionId: optionId,
      optionLabel: optionLabel,
      photoPath: photo,
      at: at,
    );

Future<MemoryJournalStore> pumpJournal(
  WidgetTester tester,
  List<JournalEntry> seed,
) async {
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final MemoryJournalStore store = MemoryJournalStore();
  for (final JournalEntry e in seed) {
    await store.add(e);
  }
  await tester.pumpWidget(
    JournalScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: const JournalPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 不注册截图字体,整张图就是一片方框 —— 而且**测试照样绿**,只有人眼看图才发现。
    await registerScreenshotFonts();
    dir = Directory.systemTemp.createTempSync('xiaoyan-journal-page');
    AppPaths.documentsDir = dir.path;
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  testWidgets('一笔都没记过 → 说清楚怎么才会有,不是白屏', (WidgetTester tester) async {
    await pumpJournal(tester, <JournalEntry>[]);

    expect(find.text('实验册还是空的'), findsOneWidget);
    expect(find.textContaining('记一笔'), findsOneWidget);
  });

  testWidgets('记过一笔 → 哪次实验、第几步、看到了什么都在', (WidgetTester tester) async {
    await pumpJournal(tester, <JournalEntry>[
      entry('a', DateTime(2026, 10, 11, 10, 30)),
    ]);

    expect(find.text('实验册还是空的'), findsNothing);
    expect(find.text('盐水浮鸡蛋'), findsOneWidget);
    expect(find.text('第 3 步 · 2026-10-11 10:30'), findsOneWidget);
    expect(find.text('沉在杯底了'), findsOneWidget);
    expect(find.text('看一看,鸡蛋在哪儿呀?'), findsOneWidget);
  });

  testWidgets('记了好几笔 → 新的摆最上面', (WidgetTester tester) async {
    await pumpJournal(tester, <JournalEntry>[
      entry('old', DateTime(2026, 10, 10, 9), optionLabel: '好像没变化'),
      entry('new', DateTime(2026, 10, 11, 9), optionLabel: '浮在水面上了'),
    ]);

    final double newTop = tester.getTopLeft(find.text('浮在水面上了')).dy;
    final double oldTop = tester.getTopLeft(find.text('好像没变化')).dy;
    expect(newTop, lessThan(oldTop), reason: '10-11 记的该排在 10-10 那笔上面');
  });

  testWidgets('照片文件不在了 → 画占位,不是红框也不是崩', (WidgetTester tester) async {
    await pumpJournal(tester, <JournalEntry>[
      entry('gone', DateTime(2026, 10, 11, 9), photo: 'photos/never-existed.jpg'),
    ]);

    expect(find.byType(Image), findsNothing, reason: '找不到文件就别去画它');
    expect(find.text('🔍'), findsOneWidget);
    expect(find.text('盐水浮鸡蛋'), findsOneWidget, reason: '照片丢了,这一笔还得在');
  });

  testWidgets('照片还在 → 画的是照片,不是占位', (WidgetTester tester) async {
    final Directory photos = Directory('${dir.path}/photos')..createSync(recursive: true);
    File('${photos.path}/ok.png').writeAsBytesSync(base64Decode(_onePixelPng));

    await pumpJournal(tester, <JournalEntry>[
      entry('shot', DateTime(2026, 10, 11, 9), photo: 'photos/ok.png'),
    ]);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('🔍'), findsNothing);
  });

  testWidgets('往左划掉一笔 → 真删了;删光了回到空态', (WidgetTester tester) async {
    final MemoryJournalStore store = await pumpJournal(tester, <JournalEntry>[
      entry('only', DateTime(2026, 10, 11, 9)),
    ]);

    await tester.drag(find.text('盐水浮鸡蛋'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(await store.all(), isEmpty, reason: '界面上划掉了,存档里也得没了');
    expect(find.text('实验册还是空的'), findsOneWidget);
  });

  testWidgets('截图:实验册里记了两笔', (WidgetTester tester) async {
    await pumpJournal(tester, <JournalEntry>[
      entry('b', DateTime(2026, 10, 11, 10, 30), optionLabel: '浮在水面上了'),
      entry('a', DateTime(2026, 10, 11, 10, 12), optionLabel: '沉在杯底了'),
    ]);

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/10-journal.png'));
  });
}
