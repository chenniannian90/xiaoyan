import 'package:flutter/material.dart';

/// 动森风的统一 token。颜色、圆角、描边、间距都从这里取,
/// 数学板块用叶子绿、科学板块用天空蓝,其余共用(设计文档 §9)。
class DesignTokens {
  const DesignTokens._();

  // 颜色
  static const Color cream = Color(0xFFFFF8E7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF4A4038);
  static const Color inkSoft = Color(0xFF8A7F73);
  static const Color outline = Color(0xFF3E3A36);

  static const Color leafGreen = Color(0xFF6BBF59);
  static const Color leafGreenDeep = Color(0xFF3F7A34);
  static const Color sunnyYellow = Color(0xFFFFC93C);
  static const Color skyBlue = Color(0xFF6EC6E8);
  static const Color skyBlueDeep = Color(0xFF2E7DA6);

  // 形状:大圆角 + 粗描边,配浅而散的影子,做出贴纸感
  static const double radiusCard = 24;
  static const double radiusChip = 16;
  static const double borderWidth = 2.5;

  // 间距:儿童界面按钮大、间距大
  static const double gapS = 8;
  static const double gap = 16;
  static const double gapL = 24;
  static const double pagePadding = 20;

  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1A3E3A36), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

ThemeData buildXiaoyanTheme() {
  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: DesignTokens.leafGreen),
    scaffoldBackgroundColor: DesignTokens.cream,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: DesignTokens.ink,
      displayColor: DesignTokens.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DesignTokens.cream,
      foregroundColor: DesignTokens.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: DesignTokens.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
