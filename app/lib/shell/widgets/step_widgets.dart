import 'package:flutter/material.dart';

import '../../engine/scene_state.dart';
import '../../engine/scene_view.dart';
import '../../mascot/dragon_hoo.dart';
import '../../theme/design_tokens.dart';
import 'sticker_card.dart';

/// 学环节和做环节共用的那几件:步点、实验台框、龙呼呼的气泡、底下那排按钮。
///
/// 两边本来各写了一份,一模一样 —— 留着就是等着哪天改了一边忘了另一边。
/// 真正不同的只有文案(「下一步」/「重播」 vs 「做完了」/「再听一遍」)和主题色。

/// 第几步 / 共几步。学环节说「步」,练环节说「题」—— 量词跟着环节走。
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.index,
    required this.total,
    this.accent = DesignTokens.leafGreen,
    this.noun = '步',
  });

  final int index;
  final int total;
  final Color accent;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          '第 ${index + 1} $noun,共 $total $noun',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DesignTokens.inkSoft,
          ),
        ),
        const Spacer(),
        for (int i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= index ? accent : DesignTokens.card,
                border: Border.all(color: DesignTokens.outline, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// 实验台的框。固定 1000:640 —— 跟画笔的设计坐标同一个比例,不裁不拉。
class SceneFrame extends StatelessWidget {
  const SceneFrame({super.key, required this.state});

  final SceneState state;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4FF),
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: DesignTokens.outline, width: DesignTokens.borderWidth),
          boxShadow: DesignTokens.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard - 2),
          child: SceneView(state: state),
        ),
      ),
    );
  }
}

/// 龙呼呼 + 它说这句话。[talking] 时张着嘴 —— 正在念的时候用。
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, required this.talking});

  final String text;
  final bool talking;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        DragonHoo(size: 96, pose: talking ? DragonPose.talking : DragonPose.idle),
        const SizedBox(width: DesignTokens.gapS),
        Expanded(
          child: StickerCard(
            padding: const EdgeInsets.all(DesignTokens.gap),
            child: Text(
              text,
              style: const TextStyle(fontSize: 19, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底下那排按钮。手指点得到(高 56),字大。
class StepControls extends StatelessWidget {
  const StepControls({
    super.key,
    required this.keys,
    required this.canBack,
    required this.canNext,
    required this.nextLabel,
    required this.replayLabel,
    required this.onBack,
    required this.onReplay,
    required this.onNext,
    this.accent = DesignTokens.leafGreen,
  });

  final StepButtonKeys keys;
  final bool canBack;
  final bool canNext;
  final String nextLabel;
  final String replayLabel;
  final VoidCallback onBack;
  final VoidCallback onReplay;
  final VoidCallback onNext;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: StepButton(
            btnKey: keys.back,
            label: '上一步',
            // 不带图标:这一格窄,三个字加个箭头就换行了(截图上真的折成三行)
            onTap: canBack ? onBack : null,
          ),
        ),
        const SizedBox(width: DesignTokens.gapS),
        Expanded(
          // 这一格要装得下「再听一遍」四个字再加个图标 —— 做环节用的就是这个文案,
          // 和「上一步」一样给 2 会把它挤到第二行、再被 maxLines:1 裁成「再听一」。
          flex: 3,
          child: StepButton(
            btnKey: keys.replay,
            label: replayLabel,
            icon: Icons.replay_rounded,
            onTap: onReplay,
          ),
        ),
        const SizedBox(width: DesignTokens.gapS),
        Expanded(
          flex: 3,
          child: StepButton(
            btnKey: keys.next,
            label: nextLabel,
            icon: nextLabel == '下一步' ? Icons.chevron_right_rounded : Icons.check_rounded,
            primary: true,
            accent: accent,
            onTap: canNext ? onNext : null,
          ),
        ),
      ],
    );
  }
}

/// 三个按钮的 key。页面自己给,测试靠它拿到 onPressed 判断"现在能不能按"。
class StepButtonKeys {
  const StepButtonKeys({required this.back, required this.replay, required this.next});

  final Key back;
  final Key replay;
  final Key next;
}

class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.btnKey,
    this.primary = false,
    this.accent = DesignTokens.leafGreen,
  });

  final String label;

  /// 可以不给:窄格子里图标会把字挤到换行。
  final IconData? icon;
  final VoidCallback? onTap;
  final Key? btnKey;
  final bool primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(DesignTokens.radiusChip);
    // 按钮的字要从主题里接,**不能自己造一个光秃秃的 TextStyle**。
    // 按钮会用 DefaultTextStyle 盖掉外层的字,主题的字体不会自动传进来:
    // 自造的样式没有字体名,截图里整排按钮就成了一片方框(这个坑见过两次了,
    // 见 docs/局限/界面截图.md)。
    final TextStyle text = (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
        .copyWith(fontSize: 17, fontWeight: FontWeight.w800);
    final EdgeInsetsGeometry pad = const EdgeInsets.symmetric(vertical: 16, horizontal: 8);

    if (primary) {
      return FilledButton.icon(
        key: btnKey,
        onPressed: onTap,
        icon: Icon(icon ?? Icons.check_rounded, size: 22),
        label: Text(label, maxLines: 1),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          padding: pad,
          textStyle: text,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      );
    }
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: DesignTokens.ink,
      side: const BorderSide(color: DesignTokens.outline, width: DesignTokens.borderWidth),
      minimumSize: const Size(0, 56),
      padding: pad,
      textStyle: text,
      shape: RoundedRectangleBorder(borderRadius: radius),
    );
    if (icon == null) {
      return OutlinedButton(
        key: btnKey,
        onPressed: onTap,
        style: style,
        child: Text(label, maxLines: 1),
      );
    }
    return OutlinedButton.icon(
      key: btnKey,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, maxLines: 1),
      style: style,
    );
  }
}
