import '../content/models.dart';
import 'scene_state.dart';
import 'timeline.dart';

/// 一块积木。
///
/// 这是整个"加内容不改引擎"的接口面:内容包的 `learn.steps[].bricks[]` 里写
/// `{"brick": "science.liquid", "params": {...}}`,执行器就去注册表里找这块积木,
/// 把它 [run] 成一段补间。**积木不认识时钟、不认识画布**,只认识
/// 「内容包给的参数」和「当前的世界状态」这两样 —— 所以它能被单独测,
/// 也能被换一个渲染器接着用。
///
/// 写新积木的规矩:
/// - 只改传进来的 [SceneState],别去碰别的地方;
/// - 返回的每个 `apply` 必须是「t 的纯函数」(见 [TweenAction] 的注释);
/// - 想"一步到位"就直接改 state 然后返回空列表 —— 摆手、摆布景就是这样。
abstract class Brick {
  const Brick();

  /// 内容包里写这个名字来引用它,必须跟 `content-schema/bricks.json` 登记的一致。
  String get name;

  /// 执行一次调用。允许直接改 [state](瞬时生效),也允许返回一串补间。
  List<TweenAction> run(BrickCall call, SceneState state);
}

/// 内容包引用了一块没实现的积木。这种情况正常不该出现(打包前
/// `tools/validate_content.py` 会拦),但真出现时要说得出是哪一块,
/// 别默默跳过让小孩对着空屏幕发呆。
class UnknownBrickException implements Exception {
  const UnknownBrickException(this.name);

  final String name;

  @override
  String toString() => '积木「$name」还没做出来(检查 content-schema/bricks.json 与 lib/bricks/registry.dart 是否对得上)';
}

/// 参数取错类型/缺了。message 里要能看出是哪块积木的哪个参数。
class BrickParamException implements Exception {
  const BrickParamException(this.message);

  final String message;

  @override
  String toString() => '积木参数不对:$message';
}

// ---- 参数读取小工具:类型不对就报「哪块积木、哪个参数」----

double numParam(BrickCall call, String key, {double? fallback}) {
  final Object? v = call.params[key];
  if (v is num) return v.toDouble();
  if (fallback != null) return fallback;
  throw BrickParamException('${call.brick} 缺参数 $key(或它不是数字)');
}

int intParam(BrickCall call, String key, {int? fallback}) {
  final Object? v = call.params[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (fallback != null) return fallback;
  throw BrickParamException('${call.brick} 缺参数 $key(或它不是整数)');
}

bool boolParam(BrickCall call, String key, {bool fallback = false}) {
  final Object? v = call.params[key];
  return v is bool ? v : fallback;
}

String strParam(BrickCall call, String key, {String? fallback}) {
  final Object? v = call.params[key];
  if (v is String && v.isNotEmpty) return v;
  if (fallback != null) return fallback;
  throw BrickParamException('${call.brick} 缺参数 $key(或它不是非空字符串)');
}

List<String> strListParam(BrickCall call, String key) {
  final Object? v = call.params[key];
  if (v is List) {
    return v.whereType<String>().toList(growable: false);
  }
  throw BrickParamException('${call.brick} 的参数 $key 应该是一串名字');
}
