import '../content/models.dart';
import '../engine/brick.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';

/// 布景:摆出实验台和器材。
///
/// 瞬时生效,不产出补间 —— 它管的是"台上有哪些东西",东西的动是别的积木的事。
/// 重复调用是**累加**不是替换:先在台上摆好杯子,下一步再补一根勺子,
/// 不该把杯子撤掉。
class SceneBrick extends Brick {
  const SceneBrick();

  @override
  String get name => 'shared.scene';

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    state.objects.addAll(strListParam(call, 'objects'));
    return const <TweenAction>[];
  }
}

/// 高亮某个对象,并在它旁边挂一句短标签(比如「鸡蛋更重」)。
/// 瞬时生效;那个呼吸的动效是画面层的事(SceneView 自己循环),不归积木管。
class HighlightBrick extends Brick {
  const HighlightBrick();

  @override
  String get name => 'shared.highlight';

  @override
  List<TweenAction> run(BrickCall call, SceneState state) {
    state.highlightTarget = strParam(call, 'target');
    state.highlightLabel = strParam(call, 'label');
    return const <TweenAction>[];
  }
}
