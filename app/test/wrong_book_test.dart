import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/shell/wrong_book_page.dart';
import 'package:xiaoyan/wrong/wrong_book.dart';
import 'package:xiaoyan/wrong/wrong_scope.dart';

import 'support/screenshot_fonts.dart';

/// 错题本:存得住、排得对、翻得了身;页面上划得掉、重练得起来。
///
/// Hive 是纯 Dart 的,`flutter test` 里能开真盒子 —— 存取测的是真的,
/// 不是 mock 自己(见 journal_store_test 同款说明)。
WrongAnswer _wrong(
  String slug,
  int itemIndex, {
  required DateTime at,
  int count = 1,
  DateTime? resolvedAt,
  String title = '合起来数一数(5 以内加法)',
}) =>
    WrongAnswer(
      slug: slug,
      itemIndex: itemIndex,
      topicTitle: title,
      prompt: '2 颗和 1 颗,合起来一共是几颗?',
      wrongCount: count,
      lastAt: at,
      resolvedAt: resolvedAt,
    );

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('xiaoyan-wrongbook');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  group('存取(Hive 真盒子)', () {
    test('记一次错,再记一次,次数叠上来、不翻身', () async {
      final HiveWrongBookStore store = HiveWrongBookStore(boxName: 'accumulate');
      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11, 9)));
      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11, 10)));

      final List<WrongAnswer> got = await store.all();
      expect(got, hasLength(1));
      expect(got.single.wrongCount, 2);
      expect(got.single.resolved, isFalse, reason: '又错了就该回到没翻身');
      expect(got.single.lastAt, DateTime(2026, 10, 11, 10));
    });

    test('翻过身又错了:清回未翻身(练过的痕迹不能挡住这次错)', () async {
      final HiveWrongBookStore store = HiveWrongBookStore(boxName: 'relapse');
      await store.recordWrong(_wrong('add-within-5', 1, at: DateTime(2026, 10, 10)));
      await store.resolve('add-within-5', 1);
      await store.recordWrong(_wrong('add-within-5', 1, at: DateTime(2026, 10, 11)));

      final List<WrongAnswer> got = await store.all();
      expect(got.single.resolved, isFalse);
      expect(got.single.wrongCount, 2);
    });

    test('排序:没翻身的在前,同组里最近错的在前', () async {
      final HiveWrongBookStore store = HiveWrongBookStore(boxName: 'order');
      // resolved(旧) / resolved(新) / 未翻身(旧) / 未翻身(新)
      await store.recordWrong(_wrong('p', 0, at: DateTime(2026, 10, 8)));
      await store.resolve('p', 0);
      await store.recordWrong(_wrong('p', 1, at: DateTime(2026, 10, 9)));
      await store.resolve('p', 1);
      await store.recordWrong(_wrong('p', 2, at: DateTime(2026, 10, 10)));
      await store.recordWrong(_wrong('p', 3, at: DateTime(2026, 10, 11)));

      final List<WrongAnswer> got = await store.all();
      expect(got.map((WrongAnswer e) => e.itemIndex).toList(), <int>[3, 2, 1, 0]);
    });

    test('关掉盒子再开,记录还在 —— 不是只活在内存里', () async {
      final HiveWrongBookStore store = HiveWrongBookStore(boxName: 'persist');
      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11), count: 3));
      await Hive.close();

      final List<WrongAnswer> got = await HiveWrongBookStore(boxName: 'persist').all();
      expect(got, hasLength(1));
      expect(got.single.wrongCount, 3);
    });

    test('没记过的题调 resolve 等于没发生;remove 能删', () async {
      final HiveWrongBookStore store = HiveWrongBookStore(boxName: 'resolve-remove');
      await store.resolve('ghost', 0);
      expect(await store.all(), isEmpty);

      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11)));
      await store.remove('add-within-5:0');
      expect(await store.all(), isEmpty);
    });

    test('内存实现语义一致', () async {
      final MemoryWrongBookStore store = MemoryWrongBookStore();
      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11)));
      await store.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 12)));
      await store.recordWrong(_wrong('add-within-5', 1, at: DateTime(2026, 10, 13)));
      await store.resolve('add-within-5', 0);

      final List<WrongAnswer> got = await store.all();
      expect(got.first.itemIndex, 1, reason: '没翻身的排前面');
      expect(got.last.resolved, isTrue);
      expect(got.last.wrongCount, 2);
    });
  });

  group('错题本页', () {
    late ContentLibrary library;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await registerScreenshotFonts();
      library = await ContentLibrary.load();
    });

    Future<MemoryWrongBookStore> pumpBook(
      WidgetTester tester, {
      MemoryWrongBookStore? store,
    }) async {
      tester.view.physicalSize = phone * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final MemoryWrongBookStore book = store ?? MemoryWrongBookStore();
      await tester.pumpWidget(
        WrongBookScope(
          store: book,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: screenshotTheme(),
            home: WrongBookPage(library: library),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return book;
    }

    testWidgets('空册也说得清楚', (WidgetTester tester) async {
      await pumpBook(tester);
      expect(find.text('错题本'), findsOneWidget);
      expect(find.text('错题本是空的'), findsOneWidget);
      expect(find.textContaining('练习里错过的题会自己跑到这里来'), findsOneWidget);
    });

    testWidgets('错着的题:橙卡、错几次、再做一次', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(
        _wrong('add-within-5', 0, at: DateTime(2026, 10, 11), count: 2),
      );
      await pumpBook(tester, store: book);

      expect(find.text('合起来数一数(5 以内加法)'), findsOneWidget);
      expect(find.text('2 颗和 1 颗,合起来一共是几颗?'), findsOneWidget);
      expect(find.text('错 2 次'), findsOneWidget);
      expect(find.byKey(const Key('wrong.redo.add-within-5:0')), findsOneWidget);
      expect(find.text('再做一次'), findsOneWidget);
    });

    testWidgets('翻身的题:绿卡、已会了、再巩固一次', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 10)));
      await book.resolve('add-within-5', 0);
      await pumpBook(tester, store: book);

      expect(find.text('已会了 ✅'), findsOneWidget);
      expect(find.text('再巩固一次'), findsOneWidget);
    });

    testWidgets('重练做对了:回来那道题翻成已会', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11)));
      await pumpBook(tester, store: book);

      await tester.tap(find.byKey(const Key('wrong.redo.add-within-5:0')));
      await tester.pumpAndSettle();
      // 进的是只练这一题的练习页
      expect(find.textContaining('第 1 题,共 1 题'), findsOneWidget);

      await tester.tap(find.byKey(const Key('practice.choice.3')));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      // 结算页出来,回头(练完页没有"回错题本",先用系统返回)
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('已会了 ✅'), findsOneWidget, reason: '重练一次做对,当场翻身');
      expect(await book.all(), isNotEmpty, reason: '翻身的留档可看,不是删掉');
    });

    testWidgets('内容包不在了:说不清楚就明说,别把人留在原地', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(
        _wrong('ghost-pack', 0, at: DateTime(2026, 10, 11), title: '被删掉的课'),
      );
      await pumpBook(tester, store: book);

      await tester.tap(find.byKey(const Key('wrong.redo.ghost-pack:0')));
      await tester.pumpAndSettle();

      expect(find.textContaining('不在了'), findsOneWidget);
      expect(find.text('错题本'), findsOneWidget, reason: '人还留在错题本页');
    });

    testWidgets('划掉就删,删完亮空册', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(_wrong('add-within-5', 0, at: DateTime(2026, 10, 11)));
      await pumpBook(tester, store: book);

      await tester.drag(
        find.byKey(const Key('wrong.redo.add-within-5:0')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(await book.all(), isEmpty);
      expect(find.text('错题本是空的'), findsOneWidget);
    });

    testWidgets('截图:错题本里躺着一道错题', (WidgetTester tester) async {
      final MemoryWrongBookStore book = MemoryWrongBookStore();
      await book.recordWrong(
        _wrong('add-within-5', 0, at: DateTime(2026, 10, 11), count: 2),
      );
      await pumpBook(tester, store: book);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/12-wrong-book.png'),
      );
    });
  });
}
