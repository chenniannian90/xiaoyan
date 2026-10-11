import 'dart:math' as math;

import 'package:flutter/animation.dart';

import '../content/models.dart';
import '../engine/brick.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';

/// 杯里的水:液面高度,以及水里化没化盐。
///
/// `solute` 决定水"变成"什么。化盐不是一瞬间的事 —— 倒进去要搅才化,
/// 但这一步只负责"水现在是盐水了",搅是 [PourBrick] 的事。
/// 这里把 `salted` 押到液面涨完那一刻才置上,免得水还没到位就先变了颜色。
class LiquidBrick extends Brick {
  const LiquidBrick();

  @override
  String get name => 'science.liquid';

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    final double to = numParam(call, 'level').clamp(0.0, 1.0);
    final String solute = strParam(call, 'solute', fallback: 'none');
    final double from = state.liquidLevel;
    final bool becomesBrine = solute == 'salt';
    const Duration rise = Duration(milliseconds: 900);

    return <TweenAction>[
      TweenAction(
        duration: rise,
        apply: (double t) => state.liquidLevel = from + (to - from) * t,
      ),
      TweenAction(
        duration: Duration.zero,
        delay: rise,
        apply: (_) => state.salted = becomesBrine,
      ),
    ];
  }
}

/// 鸡蛋在杯子里的位置与动作。
///
/// `position` 说"最后停在哪"(杯底 / 中间 / 水面),
/// `motion` 只管"怎么过去的" —— 沉是加速下坠,浮是慢慢升上来。
///
/// 鸡蛋原先摆在台子上时,这里顺手把它挪进杯子,并且**从杯口上方掉进去**:
/// 一进杯就出现在杯底会让人以为它本来就在水里,那这个实验就没看头了。
class EggBrick extends Brick {
  const EggBrick();

  @override
  String get name => 'science.egg';

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    final String position = strParam(call, 'position');
    final String motion = strParam(call, 'motion', fallback: 'none');

    final double to = switch (position) {
      'bottom' => 0,
      'middle' => 0.5,
      'surface' => 1,
      _ => throw BrickParamException(
          '${call.brick} 的 position 只能是 bottom / middle / surface,现在是 "$position"',
        ),
    };

    final double from;
    if (state.eggInCup) {
      from = state.eggLevel;
    } else {
      // 鸡蛋原先在台子上。这一步要把它挪进杯子 —— 而且**现在就把它吊到杯口上方**,
      // 不是等轮到它了才挪。
      //
      // 一开始写成"补间开始那一刻才赋 1.25",结果水还在倒的这段(第 2 步前 900ms)
      // 鸡蛋一直画在杯底 —— 一颗蛋待在还没水的空杯底,再"啪"地跳到杯口上方掉下来。
      // eggLevel 的初值是 0,而补间没轮到时不会 apply,漏的就是这一段。
      state.eggInCup = true;
      state.eggLevel = 1.25; // 杯口上方
      from = 1.25;
    }

    final bool sinking = motion == 'sink';
    return <TweenAction>[
      TweenAction(
        duration: Duration(milliseconds: sinking ? 520 : 900),
        // 掉进去是越掉越快,浮上来是先快后慢;都用同一根曲线会像在滑滑梯
        curve: sinking ? Curves.easeIn : Curves.easeOutCubic,
        apply: (double t) => state.eggLevel = from + (to - from) * t,
      ),
    ];
  }
}

/// 往杯里倒东西(盐 / 水),可选搅拌。
///
/// 一段倒 + 一段搅,两段首尾相接 —— 所以它自己内部就有先后,
/// 内容包里不用拆成两块积木。
class PourBrick extends Brick {
  const PourBrick();

  @override
  String get name => 'science.pour';

  /// 一勺大概倒多久。三勺 ≈ 1.1 秒,跟语音里「一勺、两勺、三勺」大致合得上。
  static const Duration _perSpoon = Duration(milliseconds: 380);

  /// 搅一搅要多久 —— 转两圈。
  static const Duration _stir = Duration(milliseconds: 1500);

  /// 盐堆到多满算"化不完了"。6 勺基本就到顶。
  static const double _spoonsToSaturation = 6;

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    final String item = strParam(call, 'item');
    final int spoons = intParam(call, 'spoons', fallback: 1).clamp(1, 20);
    final bool stir = boolParam(call, 'stir');

    final Duration pouring = _perSpoon * spoons;
    final List<TweenAction> out = <TweenAction>[];

    // 先把"倒完之后"的数值算出来,搅那一段要用它当起点
    // (不能等 apply 里现读 —— 那会儿拿到的已经不是构建时的 state 了)
    final double pileAfter;
    if (item == 'water') {
      final double from = state.liquidLevel;
      final double to = (from + spoons * 0.08).clamp(0.0, 1.0);
      out.add(TweenAction(
        duration: pouring,
        apply: (double t) {
          state.pouring = true;
          state.pourItem = 'water';
          state.liquidLevel = from + (to - from) * t;
        },
      ));
      pileAfter = state.saltPile;
    } else if (item == 'salt') {
      final double from = state.saltPile;
      final double to = (from + spoons / _spoonsToSaturation).clamp(0.0, 1.0);
      out.add(TweenAction(
        duration: pouring,
        apply: (double t) {
          state.pouring = true;
          state.pourItem = 'salt';
          state.saltPile = from + (to - from) * t;
        },
      ));
      pileAfter = to;
    } else {
      throw BrickParamException('${call.brick} 的 item 只能是 salt / water,现在是 "$item"');
    }

    // 倒完把"正在倒"的旗子放下,那道流才会消失
    out.add(TweenAction(
      duration: Duration.zero,
      delay: pouring,
      apply: (_) {
        state.pouring = false;
        state.pourItem = '';
      },
    ));

    if (!stir) {
      return out;
    }

    out.add(TweenAction(
      duration: _stir,
      delay: pouring,
      curve: Curves.linear, // 搅是匀速转圈,缓动反而像手抖
      apply: (double t) {
        state.stirring = true;
        state.stirAngle = t * 4 * math.pi; // 两圈
        state.saltPile = pileAfter * (1 - t); // 化掉了
      },
    ));
    out.add(TweenAction(
      duration: Duration.zero,
      delay: pouring + _stir,
      apply: (_) {
        state.stirring = false;
        state.saltPile = 0;
        state.salted = true;
      },
    ));
    return out;
  }
}
