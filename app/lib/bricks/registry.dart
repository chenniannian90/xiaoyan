import '../content/models.dart';
import '../engine/brick.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';
import 'math.dart';
import 'science.dart';
import 'shared.dart';

/// 认识的积木。
///
/// 这份清单必须跟 `content-schema/bricks.json` 对得上 —— 那个文件是给人看的契约,
/// 这里是能跑的真相;`tools/validate_content.py` 按契约拦内容包,
/// [brickNamed] 在运行时兜底(内容包引了清单外的东西会当场报出名字)。
///
/// **加一块积木 = 这里加一行 + bricks.json 加一条。** 加内容包则不用动这里。
const List<Brick> kAllBricks = <Brick>[
  SceneBrick(),
  HighlightBrick(),
  LiquidBrick(),
  EggBrick(),
  PourBrick(),
  CountersBrick(),
];

Brick brickNamed(String name) {
  for (final Brick b in kAllBricks) {
    if (b.name == name) return b;
  }
  throw UnknownBrickException(name);
}

/// 把一步里的几块积木排成一条时间线。
///
/// 顺序规则:默认一块演完再演下一块;某块写了 `parallel: true`,
/// 就跟**上一块**同组、同时开始。一组的长度取组里最长的那块。
///
/// 会就地改 [state] —— 摆布景、挂牌子这类瞬时动作在构建时就生效了。
/// 所以调用前必须先把 state 恢复成"这一步刚开始"的样子,
/// 否则重播一次就会在已经演完的画面上再叠一遍。
SceneTimeline buildStepTimeline(List<BrickCall> calls, SceneState state) {
  final List<List<TweenAction>> groups = <List<TweenAction>>[];
  for (final BrickCall call in calls) {
    final List<TweenAction> actions = brickNamed(call.brick).run(call, state);
    if (actions.isEmpty) {
      continue; // 瞬时动作(摆布景之类),没有要播的东西
    }
    if (call.parallel && groups.isNotEmpty) {
      groups.last.addAll(actions);
    } else {
      groups.add(List<TweenAction>.of(actions));
    }
  }
  return groups.isEmpty ? SceneTimeline.empty : SceneTimeline.fromGroups(groups);
}
