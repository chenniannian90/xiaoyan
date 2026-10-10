import 'package:flutter/material.dart';

import '../content/models.dart';
import '../theme/design_tokens.dart';
import 'widgets/sticker_card.dart';

/// 内容包详情。
/// 现在这一步只把内容**排出来给人看**——动画引擎(学)和分步引导(做)是下一步的事,
/// 所以这一页是纯静态的,等引擎落地后由引擎页替换掉上半部分。
class TopicDetailPage extends StatelessWidget {
  const TopicDetailPage({super.key, required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final Experiment? experiment = topic.experiment;
    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.pagePadding,
          0,
          DesignTokens.pagePadding,
          DesignTokens.pagePadding * 2,
        ),
        children: <Widget>[
          _Header(topic: topic),
          const SizedBox(height: DesignTokens.gap),
          _LearnSection(steps: topic.learn.steps),
          if (experiment != null) ...<Widget>[
            const SizedBox(height: DesignTokens.gap),
            _MaterialsSection(materials: experiment.materials),
            const SizedBox(height: DesignTokens.gap),
            _SafetySection(safety: experiment.safety, adultNote: experiment.adultNote),
            const SizedBox(height: DesignTokens.gap),
            _StepsSection(steps: experiment.steps),
            const SizedBox(height: DesignTokens.gap),
            _RecordOptionsSection(options: experiment.recordOptions),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final Color accent = topic.kind == TopicKind.math
        ? DesignTokens.leafGreen
        : DesignTokens.skyBlue;
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.gap),
      child: Row(
        children: <Widget>[
          Text(topic.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: DesignTokens.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  topic.title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_gradeLabel(topic.grade)} · ${topic.category} · ${'★' * topic.difficulty}',
                  style: TextStyle(fontSize: 14, color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnSection extends StatelessWidget {
  const _LearnSection({required this.steps});

  final List<LearnStep> steps;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '为什么会这样',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : DesignTokens.gapS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: DesignTokens.leafGreenDeep,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.gapS),
                  Expanded(
                    child: Text(steps[i].text, style: const TextStyle(fontSize: 16, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MaterialsSection extends StatelessWidget {
  const _MaterialsSection({required this.materials});

  final List<MaterialItem> materials;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '要准备的东西',
      accent: DesignTokens.skyBlueDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final MaterialItem m in materials)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.gapS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🧺', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: DesignTokens.gapS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              m.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: DesignTokens.gapS),
                            Text(
                              m.amount,
                              style: const TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
                            ),
                          ],
                        ),
                        if (m.note != null)
                          Text(
                            m.note!,
                            style: const TextStyle(fontSize: 13, color: DesignTokens.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({required this.safety, this.adultNote});

  final List<String> safety;
  final String? adultNote;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: const Color(0xFFFFF3D6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '安全提示',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFFC77700)),
          ),
          const SizedBox(height: DesignTokens.gapS),
          for (final String line in safety)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.gapS),
              // ⚠️ 单独一个 widget,别和文案拼一串 —— 内容原文要能原样找到
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('⚠️', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: DesignTokens.gapS),
                  Expanded(
                    child: Text(line, style: const TextStyle(fontSize: 15, height: 1.4)),
                  ),
                ],
              ),
            ),
          if (adultNote != null) ...<Widget>[
            const Divider(height: DesignTokens.gapL),
            Text(
              '给大人:$adultNote',
              style: const TextStyle(fontSize: 14, color: DesignTokens.inkSoft, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.steps});

  final List<ExperimentStep> steps;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '怎么做',
      accent: DesignTokens.skyBlueDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : DesignTokens.gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: DesignTokens.skyBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.gapS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(steps[i].text, style: const TextStyle(fontSize: 16, height: 1.4)),
                        if (steps[i].record)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '📷 这一步要记下来',
                              style: TextStyle(
                                fontSize: 13,
                                color: DesignTokens.skyBlueDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordOptionsSection extends StatelessWidget {
  const _RecordOptionsSection({required this.options});

  final List<RecordOption> options;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '做完可能会看到',
      accent: DesignTokens.skyBlueDeep,
      child: Wrap(
        spacing: DesignTokens.gapS,
        runSpacing: DesignTokens.gapS,
        children: <Widget>[
          for (final RecordOption o in options)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DesignTokens.cream,
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                border: Border.all(color: DesignTokens.outline, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (o.emoji != null) ...<Widget>[
                    Text(o.emoji!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(o.label, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _gradeLabel(int grade) {
  const List<String> numerals = <String>['', '一', '二', '三', '四', '五', '六'];
  if (grade < 1 || grade > 6) return '$grade 年级';
  return '${numerals[grade]}年级';
}
