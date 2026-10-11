import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/loader.dart';
import 'package:xiaoyan/content/models.dart';
import 'package:xiaoyan/engine/scene_state.dart';
import 'package:xiaoyan/engine/scene_view.dart';
import 'package:xiaoyan/shell/learn_page.dart';

import 'support/fake_speaker.dart';
import 'support/screenshot_fonts.dart';

/// 学环节页面的行为测试 + 一张截图。
///
/// 这里不能 `pumpAndSettle`:高亮呼吸是循环动画,永远静不下来,
/// 只能按秒 `pump` —— 跟上一条铁律一致(见 docs/局限/界面截图.md)。
const String _badBrickPack = '''
{
  "kind": "science", "slug": "bad", "title": "坏积木", "grade": 1,
  "category": "测试", "difficulty": 1, "emoji": "🧪",
  "learn": {"steps": [
    {"bricks": [{"brick": "shared.scene", "params": {"objects": ["cup"]}}],
     "text": "先摆个杯子", "audio": "s01.mp3"},
    {"bricks": [{"brick": "science.magic"}],
     "text": "这句话还是会念", "audio": "s02.mp3"}
  ]},
  "experiment": {
    "materials": [{"name": "杯子", "amount": "1 个"}],
    "safety": ["小心"],
    "steps": [{"text": "倒水", "audio": "e01.mp3"}],
    "recordOptions": [{"id": "a", "label": "沉"}, {"id": "b", "label": "浮"}]
  }
}
''';

Future<FakeSpeaker> pumpLearn(WidgetTester tester, Topic topic) async {
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final FakeSpeaker speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: screenshotTheme(),
      home: LearnPage(topic: topic, speaker: speaker),
    ),
  );
  await tester.pump();
  return speaker;
}

/// 「下一步」现在能不能按。按钮的 onPressed 为 null 就是灰的。
bool canPressNext(WidgetTester tester) {
  final ButtonStyleButton btn =
      tester.widget<ButtonStyleButton>(find.byKey(const Key('learn.next')));
  return btn.onPressed != null;
}

SceneState shownScene(WidgetTester tester) =>
    tester.widget<SceneView>(find.byType(SceneView)).state;

void main() {
  late Topic smokePack;
  late Topic badBrick;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
    // 内容包必须在这儿读:`testWidgets` 里跑的是假时钟,真实 IO 永远等不回来
    // (踩过一次 —— 整个测试文件就那么挂着不动)。setUpAll 是真实的异步环境。
    smokePack = await ContentRepository().load('salt-water-egg');
    badBrick = Topic.parse(_badBrickPack, origin: 'bad');
  });

  testWidgets('演完这一步才让按「下一步」,按下去世界接着上一步', (WidgetTester tester) async {
    final FakeSpeaker speaker = await pumpLearn(tester, smokePack);

    // 第 1 步只是摆布景,没有要演的东西 → 立刻就能往下走
    expect(find.textContaining('第 1 步'), findsOneWidget);
    expect(speaker.clips.single, endsWith('audio/s01.mp3'));
    expect(canPressNext(tester), isTrue);

    await tester.tap(find.byKey(const Key('learn.next')));
    await tester.pump();

    expect(find.textContaining('第 2 步'), findsOneWidget);
    expect(speaker.clips.last, endsWith('audio/s02.mp3'));
    expect(speaker.said.last, contains('清水'));
    expect(speaker.stops, greaterThan(0), reason: '换步要先把上一句掐掉');

    // 第 2 步有水 900ms + 鸡蛋 520ms,没演完之前按不了下一步
    expect(canPressNext(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(canPressNext(tester), isFalse, reason: '才演一半,还不该放行');

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(canPressNext(tester), isTrue);

    // 世界确实演到了第 2 步的终点:水 0.7,鸡蛋落底
    final SceneState scene = shownScene(tester);
    expect(scene.liquidLevel, closeTo(0.7, 0.001));
    expect(scene.eggLevel, closeTo(0, 0.001));
  });

  testWidgets('「上一步」倒回去、「重播」把这一步再演一遍', (WidgetTester tester) async {
    await pumpLearn(tester, smokePack);

    await tester.tap(find.byKey(const Key('learn.next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(canPressNext(tester), isTrue);

    // 重播:又回到"没演完"
    await tester.tap(find.byKey(const Key('learn.replay')));
    await tester.pump();
    expect(canPressNext(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(canPressNext(tester), isTrue);

    // 倒回第 1 步:世界也得跟着倒回去(水没了,鸡蛋回到台子上)
    await tester.tap(find.byKey(const Key('learn.back')));
    await tester.pump();
    expect(find.textContaining('第 1 步'), findsOneWidget);
    final SceneState scene = shownScene(tester);
    expect(scene.liquidLevel, 0);
    expect(scene.eggInCup, isFalse);
  });

  testWidgets('积木写错 → 出错误卡说清楚是哪一块,不是白屏', (WidgetTester tester) async {
    final FakeSpeaker speaker = await pumpLearn(tester, badBrick);

    await tester.tap(find.byKey(const Key('learn.next')));
    await tester.pump();

    expect(find.textContaining('第 2 步的动画没排出来'), findsOneWidget);
    expect(find.textContaining('science.magic'), findsOneWidget);
    // 话还是照念 —— 动画没了不该连讲解也丢了
    expect(speaker.said.last, contains('还是会念'));
    // 也别把人卡在这儿:错误卡上也放行,能继续往下看
    expect(canPressNext(tester), isTrue);
  });

  testWidgets('截图:第 2 步演完(水 0.7 + 鸡蛋落底 + 龙呼呼在讲)', (WidgetTester tester) async {
    await pumpLearn(tester, smokePack);

    await tester.tap(find.byKey(const Key('learn.next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 16));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/07-learn-step2.png'),
    );
  });
}
