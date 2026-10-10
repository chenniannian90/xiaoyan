import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/shell/home_page.dart';
import 'package:xiaoyan/theme/design_tokens.dart';

/// 界面截图(golden)。
///
/// 这台机器上没有模拟器也没有浏览器,所以"看一眼界面"靠这个:把页面真渲染成 PNG,
/// 落在 `test/goldens/` 下。`flutter test --update-goldens` 出图,直接 `flutter test`
/// 则拿新渲染跟存下来的图逐像素比 —— 界面被改坏了这里会红。
///
/// 字体的坑:`flutter test` 跑在一个几乎没字体的环境里,并且把"没指定字体名"的文字
/// 交给内置的 Ahem 字体 —— 那玩意每个字都画成一个方框。所以这里要干三件事:
///   1. 把文泉驿正黑注册成 `XiaoyanCJK`,unifont 注册成 `XiaoyanEmoji`;
///   2. 同样的中文字库再注册一份叫 `Roboto`,因为 Material 的默认文字样式写死了这个名字;
///   3. 把 Material 图标字体注册成 `MaterialIcons`,否则 Icons.* 也是方框。
/// 这三步只影响截图,不影响 APK —— 真机上用系统字体,Android 自己会做中文回退。
///
/// 为什么中文和 emoji 要分成两个族:同一个族里放两份字库时,引擎对汉字挑中的
/// 未必是正黑,可能挑成 unifont 的点阵字形(糊成一团)。分开之后由
/// `fontFamilyFallback` 决定先后 —— 汉字命中的是主族,emoji 落到备用族。
///
/// 为什么族名要自己起(AppBar 标题那个坑):主题里给 AppBar 标题写的是
/// `TextStyle(fontWeight: w800)`,**没写字体名**。没写字体名时引擎会挑默认字体,
/// 而默认字体就是内置的 Ahem —— 所以标题会变成一排方框。把字体注册成 `Ahem`
/// 也救不了:引擎先注册的那个 Ahem 在同一族里排前面,轮不到我们。
/// 解法是给这个标题样式补一个我们自己注册得到的族名,见 [_screenshotTheme]。
///
/// emoji 的注意:测试渲染器不认 NotoColorEmoji 的彩色点阵(CBDT/CBLC)表,
/// 所以这里退而求其次用 unifont 的单色轮廓 —— 位置、大小看得准,颜色看不出。
/// emoji 好不好看只能在手机上验,这事记在 docs/局限/界面截图.md。
const String _cjkTtc = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc';
// unifont 分两个文件:基础平面(含 ⚠ U+26A0、⚖ U+2696)和上面那些平面(含 🥚🎈🤔🧂)。
// 两个都要,否则用户看到的就是一部分 emoji 能画、一部分是方框。
const String _emojiBmpOtf = '/usr/share/fonts/opentype/unifont/unifont.otf';
const String _emojiUpperOtf = '/usr/share/fonts/opentype/unifont/unifont_upper.otf';
const String _iconOtf =
    '/root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

/// 截图专用族名,故意跟 `Roboto`/`Ahem` 错开,免得撞上引擎自带的字体。
/// unifont 的两个文件必须各占一个族:同一个族里塞两份字库时,引擎只用得上其中一份,
/// 另一份等于没注册(踩过:基础平面排前面,结果平面 1 的 emoji 全变方框)。
const String _cjkFamily = 'XiaoyanCJK';
const String _emojiBmpFamily = 'XiaoyanEmojiBmp';
const String _emojiUpperFamily = 'XiaoyanEmojiUpper';

/// 手机尺寸(逻辑像素),别用测试默认的 800×600 桌面比例,那看不出真机上的样子。
const Size _phone = Size(400, 860);

late ContentLibrary library;

Future<ByteData> _fontBytes(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('缺少字体 $path —— 没有它截图会全是方框,先装上字体再跑。');
  }
  // sublistView 是按引用包一层,不复制字节,16MB 的字体也就不会多占一份内存
  return ByteData.sublistView(file.readAsBytesSync());
}

Future<void> _registerFontFamily(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(_fontBytes(path));
  }
  await loader.load();
}

/// 截图用的主题:界面跟真实主题一模一样,只补字体信息(理由见文件头)。
/// 这不是产品设定 —— APK 里这几个族名根本不存在。
ThemeData _screenshotTheme() {
  final ThemeData base = buildXiaoyanTheme();
  const List<String> fallback = <String>[_emojiBmpFamily, _emojiUpperFamily];
  return base.copyWith(
    // 正文与标题:字体名沿用 Material 的 `Roboto`(我们把它注册成了中文),
    // 加一条 emoji 备用族兜住正黑没有的码位
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
    // AppBar 标题的样式里没写字体名,得显式补上,否则会落到内置 Ahem 上
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: _cjkFamily,
        fontFamilyFallback: fallback,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _registerFontFamily(_cjkFamily, <String>[_cjkTtc]);
    await _registerFontFamily(_emojiBmpFamily, <String>[_emojiBmpOtf]);
    await _registerFontFamily(_emojiUpperFamily, <String>[_emojiUpperOtf]);
    await _registerFontFamily('Roboto', <String>[_cjkTtc]);
    await _registerFontFamily('MaterialIcons', <String>[_iconOtf]);
    library = await ContentLibrary.load();
  });

  /// 每一张截图都把手机尺寸摆好,免得上一张的尺寸漏到下一张。
  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        title: '小妍乐园',
        debugShowCheckedModeBanner: false,
        theme: _screenshotTheme(),
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

  testWidgets('截图:数学板块空状态', (WidgetTester tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('数学乐园'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03-math-empty.png'),
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
