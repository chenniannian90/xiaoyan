import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/mascot/dragon_hoo.dart';
import 'package:xiaoyan/theme/design_tokens.dart';

import 'support/screenshot_fonts.dart';

/// 龙呼呼的**看样表**:把几种摆位、几个尺寸台阶、以及放进学环节卡片里的样子
/// 一次渲染成一张 PNG(`test/goldens/mascot-sheet.png`),供人挑。
///
/// 这张表不是回归基线,是给人看的设计稿 —— 改形象的时候
/// `flutter test --update-goldens test/mascot_sheet_test.dart` 重新出图,
/// 打开 PNG 看效果。
const Size _sheet = Size(580, 1400);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
  });

  testWidgets('看样表:摆位 / 尺寸 / 放进学环节', (WidgetTester tester) async {
    tester.view.physicalSize = _sheet * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: const _MascotSheet(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mascot-sheet.png'),
    );
  });
}

class _MascotSheet extends StatelessWidget {
  const _MascotSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.cream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Heading('头顶那对角怎么做?挑一个'),
            Wrap(
              spacing: DesignTokens.gap,
              runSpacing: DesignTokens.gap,
              children: const <Widget>[
                _Specimen(
                  '① 尖角朝上',
                  DragonVariant.coiled,
                  DragonPose.idle,
                  150,
                  horns: DragonHorns.pointed,
                ),
                _Specimen(
                  '② 往外后掠',
                  DragonVariant.coiled,
                  DragonPose.idle,
                  150,
                  horns: DragonHorns.swept,
                ),
                _Specimen(
                  '③ 不要角',
                  DragonVariant.coiled,
                  DragonPose.idle,
                  150,
                  horns: DragonHorns.none,
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.gapL),
            const _Heading('龙呼呼 · 三种摆位'),
            Wrap(
              spacing: DesignTokens.gap,
              runSpacing: DesignTokens.gap,
              children: const <Widget>[
                _Specimen('盘着坐(主形象)', DragonVariant.coiled, DragonPose.idle, 150),
                _Specimen('盘着坐 · 说话', DragonVariant.coiled, DragonPose.talking, 150),
                _Specimen('站起来', DragonVariant.upright, DragonPose.idle, 150),
                _Specimen('头像(只要头)', DragonVariant.bust, DragonPose.idle, 150),
              ],
            ),
            const SizedBox(height: DesignTokens.gapL),
            const _Heading('小尺寸的时候还认得出来吗'),
            const Wrap(
              spacing: DesignTokens.gap,
              runSpacing: DesignTokens.gap,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                _Specimen('40', DragonVariant.bust, DragonPose.idle, 40),
                _Specimen('56', DragonVariant.bust, DragonPose.idle, 56),
                _Specimen('72', DragonVariant.bust, DragonPose.idle, 72),
                _Specimen('40', DragonVariant.coiled, DragonPose.idle, 40),
                _Specimen('56', DragonVariant.coiled, DragonPose.idle, 56),
                _Specimen('72', DragonVariant.coiled, DragonPose.idle, 72),
              ],
            ),
            const SizedBox(height: DesignTokens.gapL),
            const _Heading('放进学环节(它一边说一边张嘴)'),
            const _LearnStepMock(),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.gap),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: DesignTokens.ink,
        ),
      ),
    );
  }
}

class _Specimen extends StatelessWidget {
  const _Specimen(
    this.label,
    this.variant,
    this.pose,
    this.size, {
    this.horns = DragonHorns.pointed,
  });

  final String label;
  final DragonVariant variant;
  final DragonPose pose;
  final double size;
  final DragonHorns horns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DragonHoo(variant: variant, pose: pose, horns: horns, size: size),
          const SizedBox(height: DesignTokens.gapS),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _LearnStepMock extends StatelessWidget {
  const _LearnStepMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.gap),
      decoration: BoxDecoration(
        color: DesignTokens.card,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(
          color: DesignTokens.outline,
          width: DesignTokens.borderWidth,
        ),
        boxShadow: DesignTokens.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DragonHoo(
            variant: DragonVariant.bust,
            pose: DragonPose.talking,
            size: 96,
          ),
          const SizedBox(width: DesignTokens.gap),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.gap),
              decoration: BoxDecoration(
                color: DesignTokens.cream,
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                border: Border.all(
                  color: DesignTokens.outline,
                  width: DesignTokens.borderWidth,
                ),
              ),
              child: const Text(
                '鸡蛋放进清水里,会「咚」地沉到杯底。为什么呢?',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
