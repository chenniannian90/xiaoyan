/// 截图(golden)用的字体与主题准备。
///
/// 这台机器上没有模拟器也没有浏览器,"看一眼界面"靠 `flutter test` 把页面真渲染成
/// PNG。但 `flutter test` 跑在一个几乎没字体的环境里,并且把"没指定字体名"的文字
/// 交给引擎内置的 Ahem 字体 —— 那玩意每个字都画成一个方框。所以渲染前得先把
/// 系统字库注册进去,并给主题补上字体信息。
///
/// 详细的坑与边界(哪些字体文件、为什么中文和 emoji 要分族、emoji 只有单色轮廓)
/// 记在 `docs/局限/界面截图.md`,这里只留结论与代码。
///
/// **这套东西只作用于测试渲染,跟 APK 无关** —— 真机用的是系统字体。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/theme/design_tokens.dart';

const String cjkTtc = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc';
// unifont 分两个文件:基础平面(含 ⚠ U+26A0、⚖ U+2696)和上面那些平面(含 🥚🎈🤔🧂)。
// 两个都要,否则用户看到的就是一部分 emoji 能画、一部分是方框。
const String emojiBmpOtf = '/usr/share/fonts/opentype/unifont/unifont.otf';
const String emojiUpperOtf = '/usr/share/fonts/opentype/unifont/unifont_upper.otf';
const String iconOtf =
    '/root/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

/// 截图专用族名,故意跟 `Roboto`/`Ahem` 错开,免得撞上引擎自带的字体。
/// unifont 的两个文件必须各占一个族:同一个族里塞两份字库时,引擎只用得上其中一份,
/// 另一份等于没注册(踩过:基础平面排前面,结果平面 1 的 emoji 全变方框)。
const String cjkFamily = 'XiaoyanCJK';
const String emojiBmpFamily = 'XiaoyanEmojiBmp';
const String emojiUpperFamily = 'XiaoyanEmojiUpper';

/// 手机尺寸(逻辑像素),别用测试默认的 800×600 桌面比例,那看不出真机上的样子。
const Size phone = Size(400, 860);

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

/// 把这些字库注册进测试渲染器。每个 `setUpAll` 调一次。
Future<void> registerScreenshotFonts() async {
  await _registerFontFamily(cjkFamily, <String>[cjkTtc]);
  await _registerFontFamily(emojiBmpFamily, <String>[emojiBmpOtf]);
  await _registerFontFamily(emojiUpperFamily, <String>[emojiUpperOtf]);
  // Material 的默认文字样式写死了 `Roboto`,把中文字库也注册成这个名字顶上去
  await _registerFontFamily('Roboto', <String>[cjkTtc]);
  await _registerFontFamily('MaterialIcons', <String>[iconOtf]);
}

/// 截图用的主题:界面跟真实主题一模一样,只补字体信息。
/// 这不是产品设定 —— APK 里这几个族名根本不存在。
ThemeData screenshotTheme() {
  final ThemeData base = buildXiaoyanTheme();
  const List<String> fallback = <String>[emojiBmpFamily, emojiUpperFamily];
  return base.copyWith(
    // 正文与标题:字体名沿用 Material 的 `Roboto`(我们把它注册成了中文),
    // 加一条 emoji 备用族兜住正黑没有的码位
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
    // AppBar 标题的样式里没写字体名,得显式补上,否则会落到内置 Ahem 上
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: cjkFamily,
        fontFamilyFallback: fallback,
      ),
    ),
  );
}
