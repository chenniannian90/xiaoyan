import 'package:flutter/animation.dart';

/// 一段补间:在 [duration] 内把 t 从 0 推到 1,每一帧调一次 [apply]。
///
/// [apply] 拿到的是**已经过 [curve] 的** t(0..1),所以积木里只写
/// `state.x = from + (to - from) * t` 就行,不用管缓动。
///
/// 要求 [apply] 是 t 的纯函数:同一个 t 调两次,结果必须一样。
/// 执行器会反复 seek —— 暂停、重播、拖进度全靠它 —— 带状态的写法会错乱。
class TweenAction {
  const TweenAction({
    required this.duration,
    required this.apply,
    this.delay = Duration.zero,
    this.curve = Curves.easeInOut,
  });

  final Duration duration;
  final Duration delay;
  final Curve curve;
  final void Function(double t) apply;
}

/// 一步的时间线:把这一步要用的几块积木拍平成"从第 0 毫秒起,每一刻世界该是什么样"。
///
/// 分成"组"是为了 `parallel`:内容包里一块积木标了 `parallel: true`,
/// 就是"跟上一块同时开始",而不是"等上一块演完"。
/// 冒烟包第 2 步的「倒水 + 鸡蛋沉底」是一前一后(鸡蛋不能在一滴水的空杯子里先掉下去);
/// 要是哪天写了个「水变蓝 + 同时冒泡」,就该标 parallel。
class SceneTimeline {
  const SceneTimeline._(this._placed, this.duration);

  final List<_Placed> _placed;
  final Duration duration;

  /// 用已经算好的动作搭一条时间线。
  ///
  /// [groups] 是外层"先后"、内层"同时":外层每一组依次播放,组内的动作一起开始。
  factory SceneTimeline.fromGroups(List<List<TweenAction>> groups) {
    final List<_Placed> placed = <_Placed>[];
    Duration offset = Duration.zero;
    for (final List<TweenAction> group in groups) {
      Duration span = Duration.zero;
      for (final TweenAction a in group) {
        placed.add(_Placed(start: offset + a.delay, action: a));
        final Duration end = a.delay + a.duration;
        if (end > span) span = end;
      }
      offset += span;
    }
    return SceneTimeline._(placed, offset);
  }

  static const SceneTimeline empty =
      SceneTimeline._(<_Placed>[], Duration.zero);

  /// 把世界拨到 [elapsed] 这一刻。可以往前往后反复拨,结果只取决于 [elapsed]。
  void seek(Duration elapsed) {
    for (final _Placed p in _placed) {
      p.applyAt(elapsed);
    }
  }

  /// 直接跳到结尾 —— 动画放完时世界该是什么样。
  void settle() => seek(duration + const Duration(milliseconds: 1));
}

class _Placed {
  _Placed({required this.start, required this.action});

  final Duration start;
  final TweenAction action;

  void applyAt(Duration elapsed) {
    if (elapsed <= start) {
      return; // 还没轮到它,世界保持现状
    }
    final int total = action.duration.inMicroseconds;
    final double t =
        total == 0 ? 1 : (((elapsed - start).inMicroseconds) / total).clamp(0.0, 1.0);
    action.apply(action.curve.transform(t));
  }
}
