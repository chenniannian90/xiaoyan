import 'package:flutter/animation.dart';

import '../content/models.dart';
import '../engine/brick.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';

/// 数一数:点子一颗一颗冒出来,右边再冒一组,最后可以并成一群。
///
/// 一年级讲加法最实在的画法就是这个 —— 不写"3 + 2 = 5",先让孩子**看**到
/// 三颗、两颗,再看着它们合成五颗。所以这块积木分两段:
/// 先均匀地冒出 a + b 颗(一颗一颗,别缓动,缓动就看不出"在数"),
/// 再(可选)把右边那组滑过来并上、加号同时淡出。
class CountersBrick extends Brick {
  const CountersBrick();

  @override
  String get name => 'math.counters';

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    final int a = intParam(call, 'a');
    final int b = intParam(call, 'b', fallback: 0);
    final bool join = boolParam(call, 'join');
    final int perMs = intParam(call, 'perMs', fallback: 190); // 一颗冒出来的间隔
    final int joinMs = intParam(call, 'joinMs', fallback: 620);

    if (a < 1) {
      throw BrickParamException('${call.brick} 的 a 至少是 1,现在是 $a');
    }
    if (b < 0) {
      throw BrickParamException('${call.brick} 的 b 不能是负数,现在是 $b');
    }

    // 瞬时生效:这一步一开始,台上就是"空的几个位置",点子还没冒出来。
    // 必须**现在就归零** —— 不然从已经数完的那一步倒回来,点子会一直挂在那儿
    // (补间没轮到时不会 apply,跟鸡蛋那次是同一个坑)。
    state.counterA = a;
    state.counterB = b;
    state.counterShown = 0;
    state.counterJoin = 0;

    final int total = a + b;
    final List<TweenAction> actions = <TweenAction>[
      TweenAction(
        duration: Duration(milliseconds: perMs * total),
        // 均匀 —— 用的是 linear,不是默认的 easeInOut
        curve: Curves.linear,
        apply: (double t) => state.counterShown = t * total,
      ),
    ];

    if (join && b > 0) {
      actions.add(
        TweenAction(
          duration: Duration(milliseconds: joinMs),
          curve: Curves.easeOutBack,
          apply: (double t) => state.counterJoin = t,
        ),
      );
    }
    return actions;
  }
}
