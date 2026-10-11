import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 龙呼呼 —— 小妍乐园的报幕员。
///
/// 科学小实验每一步的解说都是它念的(`tools/gen_audio.py` 用的就是 DashScope 的
/// `longhuhu_v3` 音色)。这里是它的样子:一条圆滚滚的小青龙,动森风的平涂 +
/// 粗描边 + 软阴影,颜色全部取自 [DesignTokens]。
///
/// 为什么是画出来的、不是找来的图:它得跟卡片是同一套颜色,得能换表情
/// (说话时张嘴),以后还得会点头。网上的现成素材这几样都改不动,
/// 贴上去像一张贴纸。
///
/// 它是一条**小蛇**,不是小龙。头上有两只小角是为了让它像 "longhuhu" 的龙,
/// 但身子是蛇的样子 —— 圆、软、没有腿。
enum DragonPose {
  /// 待机:抿嘴微笑。
  idle,

  /// 说话:张嘴 + 吐小舌头。
  talking,
}

/// 头顶那对角怎么做。名字叫龙呼呼,画条蛇不画角总觉得少了点什么;
/// 可是圆脑袋上放一对尖东西,一眼就是猫耳朵/兔耳朵。四种都试过,
/// 用户 2026-10-11 拍板要圆角 —— 反正换一个参数的事。
enum DragonHorns {
  /// 又短又钝的圆头小角,贴着头顶往两边微微一岔(默认,用户挑的)。
  round,

  /// 朝上、带尖。
  pointed,

  /// 往两边后掠,像小恶魔角。
  swept,

  /// 不要角,干干净净一条小蛇。
  none,
}

/// 摆位。学环节整屏解说用 [coiled],小头像位用 [bust]。
enum DragonVariant {
  /// 盘着坐,全身。主形象。
  coiled,

  /// 站起来,身子一个 S。
  upright,

  /// 只要头 + 一小截脖子。给头像位、小角标用。
  bust,
}

class DragonHoo extends StatelessWidget {
  const DragonHoo({
    super.key,
    this.variant = DragonVariant.coiled,
    this.pose = DragonPose.idle,
    this.horns = DragonHorns.round,
    this.size = 160,
  });

  final DragonVariant variant;
  final DragonPose pose;
  final DragonHorns horns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DragonHooPainter(
          variant: variant,
          pose: pose,
          horns: horns,
        ),
      ),
    );
  }
}

/// 在一个固定的 200×200 设计坐标里画,再整体缩放到控件大小 ——
/// 这样所有形状的数值都是"看着合不合理"就能定的,不用去算比例。
class _DragonHooPainter extends CustomPainter {
  const _DragonHooPainter({
    required this.variant,
    required this.pose,
    required this.horns,
  });

  final DragonVariant variant;
  final DragonPose pose;
  final DragonHorns horns;

  // 颜色:全部沿用动森风 token,不另开一套
  static const Color _body = DesignTokens.leafGreen;
  static const Color _belly = Color(0xFFFFF3D6);
  static const Color _spot = Color(0xFFA9DE9A);
  static const Color _horn = DesignTokens.sunnyYellow;
  static const Color _blush = Color(0xFFFFA8A0);
  static const Color _ink = DesignTokens.outline;
  static const Color _eyeWhite = Color(0xFFFFFFFF);
  static const Color _mouthIn = Color(0xFF8A4A44);
  static const Color _tongue = Color(0xFFFF8B8B);
  static const Color _shadow = Color(0x1A3E3A36);

  /// 设计坐标里的描边粗细。粗描边是这套画风的关键,别调小。
  static const double _line = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-100, -100);

    _paintShadow(canvas);
    _paintBody(canvas);
    _paintHorns(canvas);
    _paintHead(canvas);
    _paintFace(canvas);

    canvas.restore();
  }

  // ── 各部位的尺寸,按摆位分 ───────────────────────────────────────────

  double get _bodyWidth => switch (variant) {
        DragonVariant.coiled => 30,
        DragonVariant.upright => 26,
        DragonVariant.bust => 30,
      };

  Offset get _headCenter => switch (variant) {
        DragonVariant.coiled => const Offset(100, 60),
        DragonVariant.upright => const Offset(100, 58),
        DragonVariant.bust => const Offset(100, 100),
      };

  double get _headRx => switch (variant) {
        DragonVariant.coiled => 42,
        DragonVariant.upright => 40,
        DragonVariant.bust => 58,
      };

  double get _headRy => switch (variant) {
        DragonVariant.coiled => 36,
        DragonVariant.upright => 35,
        DragonVariant.bust => 52,
      };

  /// 肚皮往脊线的哪一侧偏。盘着的时候走的是顺时针,所以 +1 那一侧正对着
  /// 圈心 —— 肚皮朝着自己盘起来的那一面,看着才对。
  double get _bellySide => 1;

  List<Offset> get _spine {
    switch (variant) {
      case DragonVariant.coiled:
        return const <Offset>[
          Offset(100, 84), // 脖子,藏在头底下
          Offset(132, 110),
          Offset(154, 150),
          Offset(126, 182),
          Offset(80, 184),
          Offset(46, 158),
          Offset(46, 126),
          Offset(70, 112), // 尾巴尖收回来
        ];
      case DragonVariant.upright:
        return const <Offset>[
          Offset(100, 84),
          Offset(78, 110),
          Offset(106, 138),
          Offset(84, 164),
          Offset(106, 182),
        ];
      case DragonVariant.bust:
        return const <Offset>[
          Offset(100, 130),
          Offset(98, 168),
        ];
    }
  }

  // ── 各部位 ─────────────────────────────────────────────────────────

  void _paintShadow(Canvas canvas) {
    final double y = switch (variant) {
      DragonVariant.coiled => 196,
      DragonVariant.upright => 190,
      DragonVariant.bust => 174,
    };
    final double rx = switch (variant) {
      DragonVariant.coiled => 58,
      DragonVariant.upright => 26,
      DragonVariant.bust => 46,
    };
    canvas.drawOval(
      Rect.fromCenter(center: Offset(100, y), width: rx * 2, height: 14),
      Paint()..color = _shadow,
    );
  }

  void _paintBody(Canvas canvas) {
    final List<Offset> dense = _catmullRom(_spine, 24);
    final Path path = _polyPath(dense);
    final double w = _bodyWidth;

    // 先描一条更粗的深色,再描一条正色的压在上面 —— 得到一圈等宽的粗描边
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w + _line * 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _body,
    );

    if (variant == DragonVariant.bust) {
      return;
    }

    // 肚皮和背上的小点都裁在身体的管子里。
    // 肚皮是拿脊线整体朝一侧挪出来的,弯急的地方这条平行线一定会顶出绿边
    // (先红过一次:站起来那只的奶白条压到了描边上)。裁一刀就不用再担心
    // 改尺寸时又冒出来。
    canvas.save();
    canvas.clipPath(_tubePath(dense, w));

    // 肚皮:把脊线朝一侧挪一点,描成奶油色
    canvas.drawPath(
      _polyPath(_offsetPolyline(dense, _bellySide * w * 0.28, 0.10, 0.88)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.42
        ..strokeCap = StrokeCap.round
        ..color = _belly,
    );

    // 背上的小圆点
    final Paint spotPaint = Paint()..color = _spot;
    for (final double t in <double>[0.22, 0.46, 0.70]) {
      final int i = (dense.length * t).round().clamp(1, dense.length - 2);
      canvas.drawCircle(
        dense[i] + _normalAt(dense, i) * (-_bellySide * w * 0.30),
        w * 0.12,
        spotPaint,
      );
    }

    canvas.restore();
  }

  /// 两只小角。是**带尖的锥形**,不是等粗的一根。
  ///
  /// 这块返工过两次:先画成又高又细、直立的→像兔耳朵;再改成等粗的短棒往外岔
  /// →像兔耳朵放平。等粗的棒子加圆头,不管朝哪儿都还是"耳朵"。
  /// 只有"根部宽、往上收成尖"才读得出是角。
  void _paintHorns(Canvas canvas) {
    if (horns == DragonHorns.none) {
      return;
    }
    final Offset c = _headCenter;
    if (horns == DragonHorns.round) {
      // 圆头小短角:粗短的胶囊,从头顶往两边微微一岔。
      // 猫耳朵是「圆片贴在头两侧」又高又圆;角要短、要钝、要贴着头顶中线,
      // 才读得出是角不是耳朵。
      for (final double s in <double>[-1, 1]) {
        canvas.save();
        canvas.translate(c.dx + s * _headRx * 0.30, c.dy - _headRy * 0.78);
        canvas.rotate(s * 0.38);
        final Rect horn = Rect.fromCenter(
          center: Offset(0, -_headRy * 0.22),
          width: _headRx * 0.30,
          height: _headRy * 0.46,
        );
        final RRect cap = RRect.fromRectAndRadius(
          horn,
          Radius.circular(horn.width / 2),
        );
        // 和另外两款一样:先描边后填色,描边只露出外半圈
        canvas.drawRRect(
          cap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _line * 1.8
            ..color = _ink,
        );
        canvas.drawRRect(cap, Paint()..color = _horn);
        canvas.restore();
      }
      return;
    }
    final bool swept = horns == DragonHorns.swept;
    for (final double s in <double>[-1, 1]) {
      final Path horn;
      if (swept) {
        horn = Path()
          ..moveTo(c.dx + s * _headRx * 0.20, c.dy - _headRy * 0.66)
          ..quadraticBezierTo(
            c.dx + s * _headRx * 0.66,
            c.dy - _headRy * 0.94,
            c.dx + s * _headRx * 1.02,
            c.dy - _headRy * 0.70,
          )
          ..quadraticBezierTo(
            c.dx + s * _headRx * 0.72,
            c.dy - _headRy * 0.52,
            c.dx + s * _headRx * 0.46,
            c.dy - _headRy * 0.52,
          )
          ..close();
      } else {
        horn = Path()
          ..moveTo(c.dx + s * _headRx * 0.14, c.dy - _headRy * 0.74)
          ..quadraticBezierTo(
            c.dx + s * _headRx * 0.62,
            c.dy - _headRy * 1.18,
            c.dx + s * _headRx * 0.80,
            c.dy - _headRy * 1.34,
          )
          ..quadraticBezierTo(
            c.dx + s * _headRx * 0.60,
            c.dy - _headRy * 0.98,
            c.dx + s * _headRx * 0.42,
            c.dy - _headRy * 0.62,
          )
          ..close();
      }
      // 角用描边包一圈再填色,粗细才对得上身上那圈描边
      canvas.drawPath(
        horn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _line * 1.8
          ..strokeJoin = StrokeJoin.round
          ..color = _ink,
      );
      canvas.drawPath(horn, Paint()..color = _horn);
    }
  }

  void _paintHead(Canvas canvas) {
    final Rect r = Rect.fromCenter(
      center: _headCenter,
      width: _headRx * 2,
      height: _headRy * 2,
    );
    canvas.drawOval(r, Paint()..color = _ink);
    canvas.drawOval(r.deflate(_line), Paint()..color = _body);
  }

  void _paintFace(Canvas canvas) {
    final Offset c = _headCenter;
    final double ex = _headRx * 0.40;
    final double ey = -_headRy * 0.10;
    final double eyeR = _headRx * 0.27;

    // 腮红先画,压在眼睛下面
    final Paint blushPaint = Paint()..color = _blush;
    for (final double s in <double>[-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(s * _headRx * 0.68, _headRy * 0.42),
          width: _headRx * 0.44,
          height: _headRx * 0.28,
        ),
        blushPaint,
      );
    }

    // 眼睛:白眼球 + 瞳孔 + 一点高光
    for (final double s in <double>[-1, 1]) {
      final Offset eye = c + Offset(s * ex, ey);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: eyeR * 2, height: eyeR * 2.36),
        Paint()..color = _eyeWhite,
      );
      // 瞳孔略微朝中间靠,看着像在看人
      canvas.drawCircle(
        eye + Offset(-s * eyeR * 0.12, eyeR * 0.30),
        eyeR * 0.62,
        Paint()..color = _ink,
      );
      canvas.drawCircle(
        eye + Offset(-s * eyeR * 0.34, -eyeR * 0.18),
        eyeR * 0.24,
        Paint()..color = _eyeWhite,
      );
    }

    if (pose == DragonPose.talking) {
      final Rect mouth = Rect.fromCenter(
        center: c + Offset(0, _headRy * 0.52),
        width: _headRx * 0.52,
        height: _headRy * 0.60,
      );
      canvas.drawOval(mouth.inflate(_line * 0.8), Paint()..color = _ink);
      canvas.drawOval(mouth, Paint()..color = _mouthIn);
      canvas.drawOval(
        Rect.fromCenter(
          center: mouth.center + Offset(0, mouth.height * 0.22),
          width: mouth.width * 0.62,
          height: mouth.height * 0.34,
        ),
        Paint()..color = _tongue,
      );
      return;
    }

    // 抿嘴微笑:一段往下弯的弧
    final Path smile = Path()
      ..moveTo(c.dx - _headRx * 0.30, c.dy + _headRy * 0.44)
      ..quadraticBezierTo(
        c.dx,
        c.dy + _headRy * 0.72,
        c.dx + _headRx * 0.30,
        c.dy + _headRy * 0.44,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _line * 0.9
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  // ── 曲线小工具 ──────────────────────────────────────────────────────

  /// Catmull-Rom 插值:给几个控制点,得到一条穿过它们的平滑折线。
  /// 手写这个是为了控制点能像"笔顺"一样一处处点出来,不用算贝塞尔把手。
  static List<Offset> _catmullRom(List<Offset> cps, int perSeg) {
    if (cps.length < 2) {
      return List<Offset>.of(cps);
    }
    final List<Offset> p = <Offset>[cps.first, ...cps, cps.last];
    final List<Offset> out = <Offset>[];
    for (int i = 0; i + 3 < p.length; i++) {
      final Offset p0 = p[i];
      final Offset p1 = p[i + 1];
      final Offset p2 = p[i + 2];
      final Offset p3 = p[i + 3];
      for (int s = 0; s < perSeg; s++) {
        final double t = s / perSeg;
        final double t2 = t * t;
        final double t3 = t2 * t;
        out.add(
          Offset(
            0.5 *
                (2 * p1.dx +
                    (-p0.dx + p2.dx) * t +
                    (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                    (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
            0.5 *
                (2 * p1.dy +
                    (-p0.dy + p2.dy) * t +
                    (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                    (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
          ),
        );
      }
    }
    out.add(cps.last);
    return out;
  }

  static Path _polyPath(List<Offset> pts) {
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  /// 折线在 i 处的单位法线(切线逆时针转 90°)。端点用相邻点凑一个切线。
  static Offset _normalAt(List<Offset> pts, int i) {
    final Offset a = pts[i - 1];
    final Offset b = pts[i + 1];
    final Offset t = b - a;
    final double len = t.distance;
    if (len == 0) {
      return Offset.zero;
    }
    return Offset(-t.dy / len, t.dx / len);
  }

  /// 把这条折线"吹"成一圈等宽的管子,得到一个闭合区域 —— 只用来裁剪,
  /// 不直接画(画描边还是走两次 stroke,那样端头是正圆的)。
  static Path _tubePath(List<Offset> pts, double width) {
    final double h = width / 2;
    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final Offset n = _normalAt(pts, i.clamp(1, pts.length - 2));
      left.add(pts[i] + n * h);
      right.add(pts[i] - n * h);
    }
    final Path path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final Offset p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final Offset p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// 把折线上 [from, to] 这一段整体朝法线方向挪 d,得到一条平行的线。
  static List<Offset> _offsetPolyline(
    List<Offset> pts,
    double d,
    double from,
    double to,
  ) {
    final int i0 = (pts.length * from).round().clamp(1, pts.length - 2);
    final int i1 = (pts.length * to).round().clamp(1, pts.length - 2);
    final List<Offset> out = <Offset>[];
    for (int i = i0; i <= i1; i++) {
      out.add(pts[i] + _normalAt(pts, i) * d);
    }
    return out;
  }

  @override
  bool shouldRepaint(_DragonHooPainter old) =>
      old.variant != variant || old.pose != pose || old.horns != horns;
}
