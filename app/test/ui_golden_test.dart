import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/shell/home_page.dart';

import 'support/screenshot_fonts.dart';

/// 界面截图(golden)。
///
/// 这台机器上没有模拟器也没有浏览器,所以"看一眼界面"靠这个:把页面真渲染成 PNG,
/// 落在 `test/goldens/` 下。`flutter test --update-goldens` 出图,直接 `flutter test`
/// 则拿新渲染跟存下来的图逐像素比 —— 界面被改坏了这里会红。
///
/// 字体与主题的准备在 `support/screenshot_fonts.dart`,那些坑的来龙去脉记在
/// `docs/局限/界面截图.md`。
late ContentLibrary library;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerScreenshotFonts();
    library = await ContentLibrary.load();
  });

  /// 每一张截图都把手机尺寸摆好,免得上一张的尺寸漏到下一张。
  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        title: '小妍乐园',
        debugShowCheckedModeBanner: false,
        theme: screenshotTheme(),
        home: HomePage(library: library),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('截图:首页', (WidgetTester tester) async {
    await pumpPhone(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01-home.png'),
    );
  });

  testWidgets('截图:科学实验列表', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02-science-list.png'),
    );
  });

  testWidgets('截图:数学板块列表', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('数学乐园'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03-math-list.png'),
    );
  });

  testWidgets('截图:实验详情(顶部)', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盐水浮鸡蛋'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04-detail-top.png'),
    );
  });

  testWidgets('截图:实验详情(材料与安全那一段)', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盐水浮鸡蛋'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('安全提示'), 300);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05-detail-safety.png'),
    );
  });

  testWidgets('截图:实验详情(步骤那一段)', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盐水浮鸡蛋'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('做完可能会看到'), 300);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06-detail-record.png'),
    );
  });
}
