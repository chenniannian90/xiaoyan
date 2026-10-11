import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'scene_painter.dart';
import 'scene_state.dart';

/// 实验台的画面。[state] 由外面的学环节播放器持有并逐帧改动,
/// 这里只负责把它画出来,外加一个跟步骤无关的高亮呼吸。
class SceneView extends StatefulWidget {
  const SceneView({super.key, required this.state});

  final SceneState state;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 高亮标签的字从主题里取。画笔自己造 TextStyle 的话,截图环境里会掉进内置的
    // Ahem 字体(全变方框)—— 这个坑在 docs/局限/界面截图.md 里记过。
    final TextStyle labelStyle = Theme.of(context)
        .textTheme
        .titleMedium!
        .copyWith(fontWeight: FontWeight.w900, color: DesignTokens.ink);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: ScenePainter(
            state: widget.state,
            pulse: _pulse.value,
            labelStyle: labelStyle,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
