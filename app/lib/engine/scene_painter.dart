import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'scene_state.dart';

/// 把 [SceneState] 画成实验台。
///
/// 约定俗成的做法跟龙呼呼一样:所有数值都在一个固定的设计坐标里(1000×640),
/// 再整体缩放。写的时候只管"看着合不合理",不用去算比例。
///
/// 只读状态、不改状态 —— 改状态是积木的事。
class ScenePainter extends CustomPainter {
  const ScenePainter({
    required this.state,
    required this.pulse,
    required this.labelStyle,
  });

  final SceneState state;

  /// 高亮的呼吸相位,0..1。由外面一个循环的 AnimationController 喂进来,
  /// 跟步骤时间线无关 —— 高亮该一直闪着,不跟着动画走。
  final double pulse;

  /// 高亮标签用的字。从主题里拿进来,免得画笔自己造字体(截图里那样会掉进 Ahem)。
  final TextStyle labelStyle;

  // ── 设计坐标 ────────────────────────────────────────────────────────
  static const double designW = 1000;
  static const double designH = 640;
  static const Size design = Size(designW, designH);

  /// 台面后沿(= 桌面跟墙的交线)。杯子落在它下面一点,才像"放在桌面上"
  /// 而不是"贴着桌子后边站着"。
  static const double _benchTop = 512;
  static const double _cupX = 500;
  static const double _cupRimY = 130;
  static const double _cupRimHalf = 186;
  static const double _cupBaseHalf = 158;
  static const double _cupWall = 16;
  static const double _cupBaseY = 546;

  /// 内壁底 / 内壁顶。液面和鸡蛋都算在内壁坐标系里。
  static const double _innerBottom = _cupBaseY - _cupWall;
  static const double _innerTop = _cupRimY;
  static const double _innerBaseHalf = _cupBaseHalf - _cupWall;
  static const double _innerRimHalf = _cupRimHalf - _cupWall;

  /// 液面最高到这里(留一截杯口,免得水像要溢出来)。
  static const double _liquidCeil = 200;

  /// 鸡蛋。真鸡蛋差不多是杯高的六成,画小了就成了一颗药丸 ——
  /// 第一版按 96×76 画,在杯里根本认不出是鸡蛋。
  static const double _eggW = 134;
  static const double _eggH = 172;

  /// 数学的点子:半径、间距、两组分开时中间多出来的空档。
  /// 半径给到 44 是因为 1000 的设计宽在手机上要缩到三百多像素,
  /// 小了孩子数不清。
  static const double _dotR = 44;
  static const double _dotStep = 124;
  static const double _joinGap = 190;
  static const double _dotY = 306;

  static const Color _ink = DesignTokens.outline;
  static const Color _glass = Color(0x38FFFFFF);
  static const Color _glassEdge = Color(0x66FFFFFF);
  static const Color _water = Color(0x8F8ECBEF);
  static const Color _waterTop = Color(0xB3BCE3F7);
  static const Color _brine = Color(0x9FB9D9D2);
  static const Color _brineTop = Color(0xCCC9E7DE);
  static const Color _bench = Color(0xFFE3CBA6);
  static const Color _benchDeep = Color(0xFFC9A97A);
  static const Color _eggShell = Color(0xFFFFF6E2);
  static const Color _eggShade = Color(0xFFEBDCC0);

  /// 液面 y。level 0 → 杯底,1 → [_liquidCeil]。
  static double _liquidTopY(double level) =>
      _innerBottom - level.clamp(0.0, 1.0) * (_innerBottom - _liquidCeil);

  /// 内壁在某个高度上的半宽(杯子是上宽下窄的锥形)。
  static double _innerHalfAt(double y) {
    final double t = ((_innerBottom - y) / (_innerBottom - _innerTop)).clamp(0.0, 1.0);
    return _innerBaseHalf + t * (_innerRimHalf - _innerBaseHalf);
  }

  Offset get _eggCenter {
    if (!state.eggInCup) {
      // 摆在桌面上,杯子左边
      return const Offset(226, _cupBaseY - _eggH / 2);
    }
    // eggLevel 允许超过 1:鸡蛋从台子上被拿起来时是从杯口上方落进去的,
    // 那一刻它得画在杯子外面、水面上头。
    final double level = state.eggLevel.clamp(0.0, 1.3);
    final double onBottom = _innerBottom - _eggH / 2;
    final double floating = _liquidTopY(state.liquidLevel.clamp(0.0, 1.0)) - _eggH * 0.22;
    final double y = onBottom + (floating - onBottom) * math.min(level, 1.0);
    return Offset(_cupX, y - (level > 1 ? (level - 1) * 210 : 0));
  }

  Rect get _eggBounds =>
      Rect.fromCenter(center: _eggCenter, width: _eggW, height: _eggH);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width / designW, size.height / designH);
    canvas.save();
    canvas.translate((size.width - designW * s) / 2, (size.height - designH * s) / 2);
    canvas.scale(s);

    _paintWall(canvas);
    if (state.objects.contains('bench')) {
      _paintBench(canvas);
    }
    if (state.objects.contains('egg') && !state.eggInCup) {
      _paintEgg(canvas, _eggBounds);
    }
    if (state.objects.contains('cup')) {
      _paintCupBack(canvas);
      _paintLiquid(canvas);
      _paintSaltPile(canvas);
      if (state.objects.contains('egg') && state.eggInCup) {
        _paintEgg(canvas, _eggBounds);
      }
      _paintPourStream(canvas);
      _paintCupFront(canvas);
      _paintSpoon(canvas);
    }
    _paintCounters(canvas);
    _paintHighlight(canvas);

    canvas.restore();
  }

  // ── 背景 ────────────────────────────────────────────────────────────

  void _paintWall(Canvas canvas) {
    // 一大一小两个浅色圆,给背景一点层次,不至于空成一张白纸
    final Paint soft = Paint()..color = const Color(0x33FFFFFF);
    canvas.drawCircle(const Offset(180, 120), 130, soft);
    canvas.drawCircle(const Offset(840, 76), 88, soft);
    canvas.drawCircle(const Offset(690, 200), 54, Paint()..color = const Color(0x26FFF3D6));
  }

  /// 台面铺满画布底部 —— 早先画成一块悬空的板子,杯子像摆在木条上。
  /// 铺到底才读得出是"一张桌子",东西是放在桌子上的。
  void _paintBench(Canvas canvas) {
    final RRect top = RRect.fromRectAndCorners(
      const Rect.fromLTRB(-20, _benchTop, designW + 20, designH + 20),
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
    );
    canvas.drawRRect(top, Paint()..color = _ink);
    canvas.drawRRect(top.deflate(8), Paint()..color = _bench);
    // 台面前沿压一条深色,做出厚度
    canvas.drawRect(
      const Rect.fromLTRB(0, _cupBaseY + 10, designW, _cupBaseY + 24),
      Paint()..color = _benchDeep,
    );
    // 杯子在台面上投的影子
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(_cupX, _cupBaseY + 8),
        width: _cupBaseHalf * 2.3,
        height: 30,
      ),
      Paint()..color = const Color(0x223E3A36),
    );
  }

  // ── 杯子 ────────────────────────────────────────────────────────────

  /// 杯子的外轮廓(上宽下窄的锥形,底角是圆的)。
  Path _cupPath({required double halfRim, required double halfBase, required double baseY}) {
    const double r = 26;
    return Path()
      ..moveTo(_cupX - halfRim, _cupRimY)
      ..lineTo(_cupX - halfBase, baseY - r)
      ..quadraticBezierTo(_cupX - halfBase, baseY, _cupX - halfBase + r, baseY)
      ..lineTo(_cupX + halfBase - r, baseY)
      ..quadraticBezierTo(_cupX + halfBase, baseY, _cupX + halfBase, baseY - r)
      ..lineTo(_cupX + halfRim, _cupRimY)
      ..close();
  }

  /// 杯子的后壁:先画一层玻璃底,液面和鸡蛋都压在它上面。
  void _paintCupBack(Canvas canvas) {
    final Path outer = _cupPath(halfRim: _cupRimHalf, halfBase: _cupBaseHalf, baseY: _cupBaseY);
    canvas.drawPath(outer, Paint()..color = _glass);
  }

  /// 杯子的前壁:粗描边 + 一条高光,画在液体和鸡蛋之后 —— 玻璃才有"透过去"的感觉。
  void _paintCupFront(Canvas canvas) {
    final Path outer = _cupPath(halfRim: _cupRimHalf, halfBase: _cupBaseHalf, baseY: _cupBaseY);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    );
    // 左侧一道竖高光
    final Path shine = Path()
      ..moveTo(_cupX - _cupRimHalf + 30, _cupRimY + 46)
      ..lineTo(_cupX - _cupBaseHalf + 30, _cupBaseY - 74);
    canvas.drawPath(
      shine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = _glassEdge,
    );
    // 杯口那一圈
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(_cupX, _cupRimY),
        width: _cupRimHalf * 2,
        height: 34,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = _ink,
    );
  }

  void _paintLiquid(Canvas canvas) {
    final double level = state.liquidLevel.clamp(0.0, 1.0);
    if (level <= 0.001) {
      return;
    }
    final double topY = _liquidTopY(level);
    final double halfTop = _innerHalfAt(topY);
    final Path body = Path()
      ..moveTo(_cupX - halfTop, topY)
      ..lineTo(_cupX - _innerBaseHalf, _innerBottom - 20)
      ..quadraticBezierTo(
        _cupX - _innerBaseHalf,
        _innerBottom,
        _cupX - _innerBaseHalf + 20,
        _innerBottom,
      )
      ..lineTo(_cupX + _innerBaseHalf - 20, _innerBottom)
      ..quadraticBezierTo(
        _cupX + _innerBaseHalf,
        _innerBottom,
        _cupX + _innerBaseHalf,
        _innerBottom - 20,
      )
      ..lineTo(_cupX + halfTop, topY)
      ..close();

    canvas.drawPath(body, Paint()..color = state.salted ? _brine : _water);
    // 液面的椭圆:给一个"能看到水面"的角度
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_cupX, topY), width: halfTop * 2, height: 30),
      Paint()..color = state.salted ? _brineTop : _waterTop,
    );
  }

  void _paintSaltPile(Canvas canvas) {
    if (state.saltPile <= 0.001) {
      return;
    }
    final double w = 150 * state.saltPile.clamp(0.0, 1.0);
    final double h = 30 * state.saltPile.clamp(0.0, 1.0);
    final Path pile = Path()
      ..moveTo(_cupX - w / 2, _innerBottom)
      ..quadraticBezierTo(_cupX, _innerBottom - h * 2.1, _cupX + w / 2, _innerBottom)
      ..close();
    canvas.drawPath(pile, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawPath(
      pile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x33E0D6C4),
    );
  }

  /// 勺子。**只有勺头在杯底绕圈,勺柄一直朝右上伸在杯外** ——
  /// 早先是整根跟着角度转的,转到某个角度整根勺子会插到桌子底下去。
  void _paintSpoon(Canvas canvas) {
    if (!state.stirring) {
      return;
    }
    final double a = state.stirAngle;
    final Offset bowl = Offset(
      _cupX + math.cos(a) * 34,
      _innerBottom - 42 + math.sin(a) * 12,
    );
    final Offset handleTip = bowl + const Offset(158, -318);
    canvas.drawLine(
      bowl,
      handleTip,
      Paint()
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
    canvas.drawLine(
      bowl,
      handleTip,
      Paint()
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFDCDCE4),
    );
    canvas.drawCircle(bowl, 21, Paint()..color = _ink);
    canvas.drawCircle(bowl, 13, Paint()..color = const Color(0xFFEDEDF3));
  }

  /// 从杯口落下来的那道流。盐和水分开画,不然倒盐这步等于什么都没发生 ——
  /// 杯底的盐堆本来就给鸡蛋挡住了。
  void _paintPourStream(Canvas canvas) {
    if (!state.pouring || state.pourItem.isEmpty) {
      return;
    }
    final double fromY = _cupRimY - 190;
    final double toY = _innerBottom - 30;
    if (state.pourItem == 'water') {
      final Path stream = Path()
        ..moveTo(_cupX - 13, fromY)
        ..lineTo(_cupX - 17, toY)
        ..lineTo(_cupX + 17, toY)
        ..lineTo(_cupX + 13, fromY)
        ..close();
      canvas.drawPath(stream, Paint()..color = const Color(0xCC9BD4F2));
      canvas.drawPath(
        stream,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0x66FFFFFF),
      );
      return;
    }
    // 盐:一把往下滚的小颗粒。位置用下标算出来,不用随机 —— 每帧都得一样,
    // 否则截图比对会一直红。往下滚靠 pulse(外面那个循环控制器)推。
    final Paint grain = Paint()..color = const Color(0xFFFFFFFF);
    final Paint grainEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0x73A79E8C);
    for (int i = 0; i < 14; i++) {
      final double phase = (i / 14 + pulse * 2) % 1;
      final double y = fromY + phase * (toY - fromY);
      final double x = _cupX + math.sin(i * 2.399) * 32;
      canvas.drawCircle(Offset(x, y), 7, grain);
      canvas.drawCircle(Offset(x, y), 7, grainEdge);
    }
  }

  // ── 鸡蛋 ────────────────────────────────────────────────────────────

  void _paintEgg(Canvas canvas, Rect r) {
    // 影子
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.bottom + 6),
        width: r.width * 0.8,
        height: 12,
      ),
      Paint()..color = const Color(0x1F3E3A36),
    );
    canvas.drawOval(r, Paint()..color = _ink);
    canvas.drawOval(r.deflate(6), Paint()..color = _eggShell);
    // 下方一道淡淡的鸡蛋阴影,让它看起来是个立体的蛋
    canvas.drawArc(
      r.deflate(6),
      math.pi * 0.18,
      math.pi * 0.64,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = _eggShade,
    );
  }

  // ── 数一数用的点子(数学)──────────────────────────────────────────

  /// 点子。左组 a 颗、右组 b 颗,中间夹个加号;`counterJoin` 推上去时
  /// 空档收窄、两组并成一群,加号同时淡掉 —— "3 颗和 2 颗合起来是 5 颗"。
  ///
  /// 每一帧都是状态 + pulse 的纯函数(所有位置都是算出来的,没有随机),
  /// 不然截图比对会一直红。
  void _paintCounters(Canvas canvas) {
    final int a = state.counterA;
    final int b = state.counterB;
    if (a + b == 0) {
      return;
    }
    final double join = state.counterJoin.clamp(0.0, 1.0);
    final double gap = b == 0 ? 0 : _joinGap * (1 - join);
    final double totalW = (a + b) * _dotStep + gap;
    final double x0 = (designW - totalW) / 2 + _dotStep / 2;

    Offset centerOf(int k) => k < a
        ? Offset(x0 + k * _dotStep, _dotY)
        // 右组第 j 颗(k = a + j):让两组分开时中间正好空出一个 _joinGap
        : Offset(x0 + (a + k) * _dotStep + gap, _dotY);

    for (int k = 0; k < a + b; k++) {
      // age:>1 已经数过了,0..1 正在冒出来,<=0 还没轮到
      final double age = state.counterShown - k;
      if (age <= 0) break;
      // 冒出来那一下带点弹(easeOutBack 会冲到 1 之上,夹一下免得点子突然变大)
      final double pop = age >= 1 ? 1 : Curves.easeOutBack.transform(age).clamp(0.0, 1.15);
      _dot(canvas, centerOf(k), _dotR * pop);
    }

    // 加号:左组数完了才出来,并组开始就淡走
    if (b > 0 && join < 0.999) {
      final double showedLeft = (state.counterShown - (a - 1)).clamp(0.0, 1.0);
      final double alpha = showedLeft * (1 - join);
      if (alpha > 0.01) {
        _plus(canvas, Offset(x0 + (a - 0.5) * _dotStep + gap / 2, _dotY), alpha);
      }
    }
  }

  void _dot(Canvas canvas, Offset c, double r) {
    if (r <= 0.5) return;
    canvas.drawCircle(c, r, Paint()..color = _ink);
    canvas.drawCircle(c, r - 7, Paint()..color = DesignTokens.sunnyYellow);
    canvas.drawCircle(
      c + Offset(-r * 0.28, -r * 0.30),
      r * 0.22,
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  void _plus(Canvas canvas, Offset at, double alpha) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '+',
        style: labelStyle.copyWith(
          fontSize: 74,
          fontWeight: FontWeight.w900,
          color: _ink.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  // ── 高亮 ────────────────────────────────────────────────────────────

  void _paintHighlight(Canvas canvas) {
    final String? target = state.highlightTarget;
    if (target == null) {
      return;
    }
    final Rect? bounds = switch (target) {
      'egg' when state.objects.contains('egg') => _eggBounds,
      'cup' when state.objects.contains('cup') => Rect.fromLTRB(
          _cupX - _cupRimHalf,
          _cupRimY - 18,
          _cupX + _cupRimHalf,
          _cupBaseY + 10,
        ),
      'bench' when state.objects.contains('bench') =>
        const Rect.fromLTRB(40, _benchTop, designW - 40, designH - 40),
      _ => null,
    };
    if (bounds == null) {
      return;
    }

    final double breathe = 0.5 - 0.5 * math.cos(pulse * 2 * math.pi);
    final Rect ringRect = bounds.inflate(16 + 12 * breathe);
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..color = DesignTokens.sunnyYellow.withValues(alpha: 0.35 + 0.45 * breathe);
    if (target == 'egg') {
      // 鸡蛋是椭圆的,套个圆环才贴
      canvas.drawOval(ringRect, ringPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(ringRect, const Radius.circular(34)),
        ringPaint,
      );
    }

    final String? label = state.highlightLabel;
    if (label == null || label.isEmpty) {
      return;
    }
    _paintLabelChip(canvas, label, bounds);
  }

  void _paintLabelChip(Canvas canvas, String label, Rect target) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    const double padH = 20;
    const double padV = 12;
    final double w = tp.width + padH * 2;
    final double h = tp.height + padV * 2;
    // 摆在目标上方;碰到画布顶就翻到下面去
    double top = target.top - h - 26;
    if (top < 12) {
      top = target.bottom + 26;
    }
    final RRect chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (_cupX - w / 2).clamp(12, designW - w - 12),
        top,
        w,
        h,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(chip, Paint()..color = _ink);
    canvas.drawRRect(chip.deflate(5), Paint()..color = DesignTokens.sunnyYellow);
    tp.paint(canvas, Offset(chip.left + padH, chip.top + padV));
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.pulse != pulse || !identical(old.state, state) || old.labelStyle != labelStyle;
}
