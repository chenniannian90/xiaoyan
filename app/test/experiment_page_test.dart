import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/loader.dart';
import 'package:xiaoyan/content/models.dart';
import 'package:xiaoyan/journal/journal_entry.dart';
import 'package:xiaoyan/journal/journal_scope.dart';
import 'package:xiaoyan/journal/journal_store.dart';
import 'package:xiaoyan/media/photo_taker.dart';
import 'package:xiaoyan/shell/experiment_page.dart';

import 'support/fake_speaker.dart';
import 'support/screenshot_fonts.dart';

/// 做—记这条路:走到"要记一笔"的那一步 → 说出看到了什么 → 存进实验册。
///
/// 冒烟包(`salt-water-egg`)的做环节有 6 步,第 3 步和第 6 步标了 `record: true`。
/// 这几步都没有积木,所以这一页不会跑循环动画,`pumpAndSettle` 是安全的。
class ExperimentHarness {
  ExperimentHarness(this.speaker, this.store);

  final FakeSpeaker speaker;
  final MemoryJournalStore store;
}

Future<ExperimentHarness> pumpExperiment(
  WidgetTester tester,
  Topic topic, {
  String? photo,
}) async {
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final FakeSpeaker speaker = FakeSpeaker();
  final MemoryJournalStore store = MemoryJournalStore();
  await tester.pumpWidget(
    JournalScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: ExperimentPage(
          topic: topic,
          speaker: speaker,
          photoTaker: StubPhotoTaker(path: photo),
        ),
      ),
    ),
  );
  await tester.pump();
  return ExperimentHarness(speaker, store);
}

/// 按几次「下一步」。冒烟包第 3 步是第一个要记的,所以按 2 次就到。
Future<void> stepForward(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.tap(find.byKey(const Key('experiment.next')));
    await tester.pump();
  }
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('experiment.record')));
  await tester.pumpAndSettle();
}

/// 按钮的 onPressed 是 null 就是灰的。
bool enabled(WidgetTester tester, Key key) =>
    tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;

void main() {
  late Topic pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
    // 真内容包在 setUpAll 里读:testWidgets 是假时钟,真实 IO 在里面等不回来
    pack = await ContentRepository().load('salt-water-egg');
  });

  testWidgets('只有标了「要记」的那一步才冒出「记一笔」', (WidgetTester tester) async {
    await pumpExperiment(tester, pack);

    expect(find.textContaining('第 1 步'), findsOneWidget);
    expect(find.byKey(const Key('experiment.record')), findsNothing);
    expect(find.textContaining('这一步要记下来'), findsNothing);

    await stepForward(tester, 2);
    expect(find.textContaining('第 3 步'), findsOneWidget);
    expect(find.textContaining('这一步要记下来'), findsOneWidget);
    expect(find.byKey(const Key('experiment.record')), findsOneWidget);

    // 第 4 步又没了
    await stepForward(tester, 1);
    expect(find.textContaining('第 4 步'), findsOneWidget);
    expect(find.byKey(const Key('experiment.record')), findsNothing);
  });

  testWidgets('不挑现象存不了;挑一个存下去,卡片和实验册里都有了', (WidgetTester tester) async {
    final ExperimentHarness h = await pumpExperiment(tester, pack);
    await stepForward(tester, 2);
    await openSheet(tester);

    expect(find.text('你看到了什么?'), findsOneWidget);
    expect(enabled(tester, const Key('record.save')), isFalse, reason: '什么都没挑,不该能存');

    await tester.tap(find.text('沉在杯底了'));
    await tester.pump();
    expect(enabled(tester, const Key('record.save')), isTrue);

    await tester.tap(find.byKey(const Key('record.save')));
    await tester.pumpAndSettle();

    // 卡片上写着自己刚记的那一笔
    expect(find.textContaining('已记:沉在杯底了'), findsOneWidget);
    expect(find.textContaining('已记:'), findsOneWidget, reason: '只记了一笔');

    // 实验册里也真有一笔,而且记的是"这一步"
    final List<JournalEntry> saved = await h.store.all();
    expect(saved, hasLength(1));
    expect(saved.single.slug, 'salt-water-egg');
    expect(saved.single.title, '盐水浮鸡蛋');
    expect(saved.single.stepIndex, 2);
    expect(saved.single.optionId, 'sunk');
    expect(saved.single.optionLabel, '沉在杯底了');
    expect(saved.single.photoPath, isNull);
    expect(saved.single.stepText, contains('鸡蛋在哪儿'));
  });

  testWidgets('照片拍成了就带上,卡片上标出来', (WidgetTester tester) async {
    final ExperimentHarness h = await pumpExperiment(tester, pack, photo: 'photos/1712.jpg');
    await stepForward(tester, 2);
    await openSheet(tester);

    expect(find.text('拍张照片(可以不拍)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('record.photo')));
    await tester.pumpAndSettle();
    expect(find.text('照片拍好了,再拍一张'), findsOneWidget);

    await tester.tap(find.text('浮在水面上了'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('record.save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已记:浮在水面上了(带照片)'), findsOneWidget);
    expect((await h.store.all()).single.photoPath, 'photos/1712.jpg');
  });

  testWidgets('拍照没成也不是死路:说清楚,照样能记', (WidgetTester tester) async {
    final ExperimentHarness h = await pumpExperiment(tester, pack); // StubPhotoTaker(path: null)
    await stepForward(tester, 2);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('record.photo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('没拍成'), findsOneWidget);

    await tester.tap(find.text('好像没变化'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('record.save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已记:好像没变化'), findsOneWidget);
    expect(find.textContaining('(带照片)'), findsNothing);
    expect((await h.store.all()).single.photoPath, isNull);
  });

  testWidgets('一步一步念到第 6 步,「做完了」把这一页收掉', (WidgetTester tester) async {
    final ExperimentHarness h = await pumpExperiment(tester, pack);
    for (int i = 0; i < 5; i++) {
      await stepForward(tester, 1);
    }
    expect(find.textContaining('第 6 步'), findsOneWidget);
    expect(find.text('做完了'), findsOneWidget);
    expect(h.speaker.clips.last, endsWith('audio/e06.mp3'));
    expect(h.speaker.stops, greaterThan(0), reason: '换步要先掐掉上一句');
  });

  testWidgets('底下三个按钮的字都得整整齐齐,不许被挤到换行', (WidgetTester tester) async {
    await pumpExperiment(tester, pack);

    // 「再听一遍」比「重播」长两个字,窄格子里会被挤到第二行、再被 maxLines:1 裁掉
    // —— 截图上看着是「再听一」。这里把它钉住。
    for (final String label in <String>['上一步', '再听一遍', '下一步']) {
      final RenderParagraph p = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: '「$label」在按钮里被挤断了 —— 要么加宽按钮,要么把 label 改短',
      );
    }
  });

  testWidgets('截图:记一笔的弹层', (WidgetTester tester) async {
    await pumpExperiment(tester, pack, photo: 'photos/1712.jpg');
    await stepForward(tester, 2);
    await openSheet(tester);
    await tester.tap(find.text('沉在杯底了'));
    await tester.pump();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/08-record-sheet.png'));
  });

  testWidgets('截图:第 3 步记完了的样子', (WidgetTester tester) async {
    await pumpExperiment(tester, pack);
    await stepForward(tester, 2);
    await openSheet(tester);
    await tester.tap(find.text('悬在中间,不上不下'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('record.save')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/09-experiment-recorded.png'),
    );
  });
}
