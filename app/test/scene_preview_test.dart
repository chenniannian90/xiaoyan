import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/engine/scene_state.dart';
import 'package:xiaoyan/engine/scene_view.dart';

import 'support/screenshot_fonts.dart';

/// 实验台画面的**看样表**:把「盐水浮鸡蛋」五步各自的终态、外加倒盐/搅拌两个
/// 中间态,一次渲染成 `test/goldens/scene-preview.png`。
///
/// 跟 `mascot_sheet_test.dart` 一样,这是给人看的稿,不是回归基线 ——
/// 调画面的时候 `flutter test --update-goldens test/scene_preview_test.dart` 重新出图。
const Size _sheet = Size(560, 1760);

SceneState _base() => SceneState()..objects.addAll(<String>['bench', 'cup', 'egg']);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
  });

  testWidgets('看样表:实验台五步 + 倒盐/搅拌中间态', (WidgetTester tester) async {
    tester.view.physicalSize = _sheet * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: const _SceneSheet(),
      ),
    );
    // 这里不能 pumpAndSettle:高亮是循环动画,永远静不下来
    await tester.pump(const Duration(milliseconds: 16));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scene-preview.png'),
    );
  });
}

class _SceneSheet extends StatelessWidget {
  const _SceneSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAD8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Frame('第 1 步 · 台上摆好:台子 / 杯子 / 鸡蛋', _base()),
            _Frame('第 2 步 · 倒水到 0.7,鸡蛋沉底', _step2()),
            _Frame('第 3 步 · 高亮鸡蛋 +「鸡蛋更重」', _step3()),
            _Frame('第 4 步中 · 正往杯里倒盐(3 勺)', _step4a()),
            _Frame('第 4 步中 · 正在搅', _step4b()),
            _Frame('第 4 步末 · 盐化完了', _step4c()),
            _Frame('第 5 步 · 加盐后鸡蛋浮起来', _step5()),
          ],
        ),
      ),
    );
  }

  SceneState _step2() => _base()
    ..liquidLevel = 0.7
    ..eggInCup = true
    ..eggLevel = 0;

  SceneState _step3() => _step2()
    ..highlightTarget = 'egg'
    ..highlightLabel = '鸡蛋更重';

  SceneState _step4a() => _step3()
    ..highlightTarget = null
    ..highlightLabel = null
    ..pouring = true
    ..pourItem = 'salt'
    ..saltPile = 0.55;

  SceneState _step4b() => _step4a()
    ..stirring = true
    ..stirAngle = 2.1;

  SceneState _step4c() => _step4b()
    ..stirring = false
    ..pouring = false
    ..pourItem = ''
    ..saltPile = 0
    ..salted = true;

  SceneState _step5() => _step4c()..eggLevel = 1;
}

class _Frame extends StatelessWidget {
  const _Frame(this.label, this.state);

  final String label;
  final SceneState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 480,
              height: 308, // 跟设计画布同比例,免得两边留白看不出真实构图
              color: const Color(0xFFFFF8E7),
              child: SceneView(state: state),
            ),
          ),
        ],
      ),
    );
  }
}
