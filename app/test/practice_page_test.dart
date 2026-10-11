import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/loader.dart';
import 'package:xiaoyan/content/models.dart';
import 'package:xiaoyan/practice/templates.dart';
import 'package:xiaoyan/shell/learn_page.dart';
import 'package:xiaoyan/shell/practice_page.dart';
import 'package:xiaoyan/wrong/wrong_book.dart';
import 'package:xiaoyan/wrong/wrong_scope.dart';

import 'support/fake_speaker.dart';
import 'support/screenshot_fonts.dart';

/// 练环节:判题、得星、温柔的重试、连错送回学、错题入册。
///
/// 数学包(add-within-5)的题面点子动画是有限的(每颗 260ms,播完就停),
/// 彩带也是有限的(1.6s),所以这里 `pumpAndSettle` 是安全的 ——
/// 不像学环节有循环的呼吸高亮。
///
/// harness 垫了一个真的「首页」起点:练完的「回到首页」是 popUntil(isFirst),
/// 直接把 PracticePage 当 home 的话它会原地不动,测不出真实栈的样子。
class PracticeHarness {
  PracticeHarness(this.speaker, this.wrongBook);

  final FakeSpeaker speaker;
  final MemoryWrongBookStore wrongBook;
}

Future<PracticeHarness> pumpPractice(
  WidgetTester tester, {
  required Topic topic,
  Set<int>? only,
}) async {
  tester.view.physicalSize = phone * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final FakeSpeaker speaker = FakeSpeaker();
  final MemoryWrongBookStore wrongBook = MemoryWrongBookStore();
  await tester.pumpWidget(
    WrongBookScope(
      store: wrongBook,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: Scaffold(
          key: const Key('home.root'),
          body: Builder(
            builder: (BuildContext context) => Center(
              child: FilledButton(
                key: const Key('home.go-practice'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PracticePage(topic: topic, only: only, speaker: speaker),
                  ),
                ),
                child: const Text('去练习'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home.go-practice')));
  await tester.pumpAndSettle();
  return PracticeHarness(speaker, wrongBook);
}

/// 按数字点选项。按钮的 key 带着数字本身,不赌打乱后的位置。
Future<void> pick(WidgetTester tester, int value) async {
  await tester.tap(find.byKey(Key('practice.choice.$value')));
  await tester.pumpAndSettle();
}

void main() {
  late Topic pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
    pack = await ContentRepository().load('add-within-5');
  });

  testWidgets('进题:题面点子、龙呼呼的问句、三个选项都在', (WidgetTester tester) async {
    final PracticeHarness h = await pumpPractice(tester, topic: pack);

    expect(find.textContaining('第 1 题,共 3 题'), findsOneWidget);
    expect(find.text('2 颗和 1 颗,合起来一共是几颗?'), findsOneWidget);
    // 三个选项,数字对得上(add-within-5 第 1 题 choices = [2,3,4])
    for (final int n in <int>[2, 3, 4]) {
      expect(find.byKey(Key('practice.choice.$n')), findsOneWidget);
    }
    // 开场白把题目念了,还邀她挑数字(这两句只进喇叭,不上屏幕)
    expect(h.speaker.said.first, contains('2 颗和 1 颗'));
    expect(h.speaker.said.first, contains('挑一个数字'));
  });

  testWidgets('一次答对:夸一句、彩带飘完进下一题', (WidgetTester tester) async {
    final PracticeHarness h = await pumpPractice(tester, topic: pack);

    await pick(tester, 3); // 第 1 题答案
    expect(find.textContaining('第 2 题'), findsOneWidget);
    // 彩带飘完后下一题开念,所以夸奖不能赌 said.last,得 contains
    expect(h.speaker.said, contains('答对啦,你真棒!'));
    expect(await h.wrongBook.all(), isEmpty, reason: '没错过不该进错题本');
  });

  testWidgets('答错:留在原题、亮提示、进错题本;再答对就翻身', (WidgetTester tester) async {
    final PracticeHarness h = await pumpPractice(tester, topic: pack);

    await pick(tester, 2); // 错
    expect(find.textContaining('第 1 题'), findsOneWidget, reason: '错了不该偷偷跳题');
    expect(find.textContaining('💡'), findsOneWidget, reason: '答错要亮提示');
    expect(h.speaker.said.last, contains('再想一想'));

    final List<WrongAnswer> recorded = await h.wrongBook.all();
    expect(recorded, hasLength(1));
    expect(recorded.single.slug, 'add-within-5');
    expect(recorded.single.itemIndex, 0);
    expect(recorded.single.wrongCount, 1);
    expect(recorded.single.resolved, isFalse);

    await pick(tester, 3); // 对
    final List<WrongAnswer> after = await h.wrongBook.all();
    expect(after.single.resolved, isTrue, reason: '错过的题重做对了,要翻身');
  });

  testWidgets('连错 3 次:亮「再看一遍动画」,还能继续答', (WidgetTester tester) async {
    final PracticeHarness h = await pumpPractice(tester, topic: pack);

    expect(find.byKey(const Key('practice.relearn')), findsNothing);
    await pick(tester, 2);
    await pick(tester, 2);
    await pick(tester, 2);
    expect(find.byKey(const Key('practice.relearn')), findsOneWidget);
    expect(h.speaker.said.last, contains('看一遍动画'));

    await pick(tester, 2); // 第 4 次错:次数照记,不因为送过回学就停表
    final List<WrongAnswer> recorded = await h.wrongBook.all();
    expect(recorded.single.wrongCount, 4);

    await pick(tester, 3); // 最后答对,照样能进下一题
    expect(find.textContaining('第 2 题'), findsOneWidget);
  });

  testWidgets('连错送回学:回来还是这道题,机会重新给', (WidgetTester tester) async {
    await pumpPractice(tester, topic: pack);

    await pick(tester, 2);
    await pick(tester, 2);
    await pick(tester, 2);
    await tester.tap(find.byKey(const Key('practice.relearn')));
    // 学环节的呼吸高亮是循环动画,pumpAndSettle 永远等不完(docs/局限/动画引擎选型.md),
    // 按路由转场的时长泵
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // add-within-5 讲「合起来」的是第 3 步(最后一块 math.counters 带 join)
    expect(find.textContaining('第 3 步,共 3 步'), findsOneWidget);

    // 练习页还在栈底下,返回键同时挂着俩 —— 点学环节自己那颗
    await tester.tap(
      find.descendant(of: find.byType(LearnPage), matching: find.byTooltip('Back')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('第 1 题'), findsOneWidget, reason: '看完回来还是原来那道题');
  });

  testWidgets('全部做完:结算页亮出星星和鼓励,回得到首页', (WidgetTester tester) async {
    await pumpPractice(tester, topic: pack);

    await pick(tester, 3); // 题 1 对
    await pick(tester, 5); // 题 2 对
    await pick(tester, 5); // 题 3 对

    expect(find.text('练完啦!'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('⭐⭐⭐'), findsOneWidget);
    expect(find.textContaining('全对'), findsOneWidget);

    await tester.tap(find.byKey(const Key('practice.home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.root')), findsOneWidget, reason: '回到的是垫底的首页');
  });

  testWidgets('错过再对的题不给星:结算页星星少一颗', (WidgetTester tester) async {
    await pumpPractice(tester, topic: pack);

    await pick(tester, 2); // 题 1 错一次
    await pick(tester, 3); // 题 1 对(不给星)
    await pick(tester, 5); // 题 2 对
    await pick(tester, 5); // 题 3 对

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('⭐⭐☆'), findsOneWidget);
  });

  testWidgets('错题重练(only):只练指定的那一题', (WidgetTester tester) async {
    await pumpPractice(tester, topic: pack, only: const <int>{1});

    expect(find.textContaining('第 1 题,共 1 题'), findsOneWidget);
    expect(find.text('1 颗和 4 颗,合起来一共是几颗?'), findsOneWidget);

    await pick(tester, 5);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('截图:答对飘彩带的那一下', (WidgetTester tester) async {
    await pumpPractice(tester, topic: pack);

    await tester.tap(find.byKey(const Key('practice.choice.3')));
    // 彩带飘到一半,截这一帧(位置全算出来,没有随机,帧是定的)
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/11-practice-confetti.png'),
    );
    // 把剩下的 1.1 秒走完,别留挂着的 timer
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
  });

  group('练习模板注册表', () {
    test('counters-add:选项乱序但确定,答案一定在选项里', () {
      final PracticeItem item = PracticeItem(
        template: 'counters-add',
        data: const <String, dynamic>{
          'a': 3, 'b': 2, 'answer': 5, 'choices': <int>[5, 4, 6],
        },
      );
      final MathQuestion q1 = templateNamed('counters-add').build(item);
      final MathQuestion q2 = templateNamed('counters-add').build(item);
      expect(q1.choices, q2.choices, reason: '同一道题两次出的选项顺序必须一样');
      expect(q1.choices, containsAll(<int>[5, 4, 6]));
      expect(q1.choices.length, 3, reason: '重复的选项该被去掉');
      expect(q1.answer, 5);
      expect(q1.ask, contains('3 颗和 2 颗'));
      expect(q1.hint, isNull);
    });

    test('counters-add:choices 不含答案 → 建题就报,不是画到一半才炸', () {
      final PracticeItem bad = PracticeItem(
        template: 'counters-add',
        data: const <String, dynamic>{
          'a': 1, 'b': 1, 'answer': 2, 'choices': <int>[3, 4],
        },
      );
      expect(
        () => templateNamed('counters-add').build(bad),
        throwsA(isA<StateError>()
            .having((StateError e) => e.message, 'message', contains('正确答案 2'))),
      );
    });

    test('不认识的模板 → 报名字', () {
      expect(
        () => templateNamed('math.soroban'),
        throwsA(isA<UnknownTemplateException>()),
      );
    });
  });
}
