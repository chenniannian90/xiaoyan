import 'package:flutter/material.dart';

import '../audio/speaker.dart';
import '../bricks/registry.dart';
import '../content/models.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';
import '../journal/journal_entry.dart';
import '../journal/journal_scope.dart';
import '../media/photo_taker.dart';
import '../theme/design_tokens.dart';
import 'widgets/step_widgets.dart';
import 'widgets/sticker_card.dart';

/// 做环节:一步一步念给小妍听,她自己动手。
///
/// 跟学环节不同的是,**主动权在这一页之外** —— 页面上写的只是"该做什么",
/// 真正做的人是屏幕前那个小孩。所以这里不做对错判断,只在她自己说"做完了、
/// 我看到的是这样"的时候,把那一笔记进实验册。
///
/// 内容包里的 `record: true` 就是"这一步做完该记一笔"。
class ExperimentPage extends StatefulWidget {
  const ExperimentPage({super.key, required this.topic, this.speaker, this.photoTaker});

  final Topic topic;

  /// 测试塞假的进来(音频插件在测试环境里跑不起来)。
  final Speaker? speaker;
  final PhotoTaker? photoTaker;

  @override
  State<ExperimentPage> createState() => _ExperimentPageState();
}

class _ExperimentPageState extends State<ExperimentPage>
    with SingleTickerProviderStateMixin {
  static const StepButtonKeys _keys = StepButtonKeys(
    back: Key('experiment.back'),
    replay: Key('experiment.replay'),
    next: Key('experiment.next'),
  );

  late final Speaker _speaker = widget.speaker ?? PhoneSpeaker();
  late final PhotoTaker _photo = widget.photoTaker ?? const CameraPhotoTaker();
  late final AnimationController _clock = AnimationController(vsync: this);

  late final Experiment _exp = widget.topic.experiment!;
  late final List<ExperimentStep> _steps = _exp.steps;

  int _index = 0;

  /// 这一次做下来已经记了几笔(按步骤下标存,一步可能记多笔)。
  final Map<int, List<JournalEntry>> _recorded = <int, List<JournalEntry>>{};

  // ── 演示动画 ────────────────────────────────────────────────────────
  // 做环节里的步骤可以带积木(比如"这一步杯子里的水会变蓝"当个示范)。
  // 冒烟包没用到,但契约里允许,就不能默默不播 —— 用的是跟学环节同一套机制。
  late final bool _hasScene = _steps.any((ExperimentStep s) => s.bricks.isNotEmpty);
  final SceneState _scene = SceneState();
  late final List<SceneState> _starts;
  late final List<Object?> _errors;
  SceneTimeline _timeline = SceneTimeline.empty;
  Duration _span = Duration.zero;
  bool _stepDone = true;

  @override
  void initState() {
    super.initState();
    _precompute();
    _clock.addListener(_onTick);
    _clock.addStatusListener(_onStatus);
    _enter(0);
  }

  @override
  void dispose() {
    _clock.dispose();
    _speaker.dispose();
    super.dispose();
  }

  void _precompute() {
    final SceneState walk = SceneState();
    _starts = <SceneState>[];
    _errors = <Object?>[];
    for (final ExperimentStep step in _steps) {
      _starts.add(walk.clone());
      try {
        buildStepTimeline(step.bricks, walk).settle();
        _errors.add(null);
      } catch (e) {
        _errors.add(e);
      }
    }
  }

  void _onTick() {
    _timeline.seek(_span * _clock.value);
    setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _timeline.settle(); // 收尾那一拍 isAnimating 已经为 false,得自己补上终点
    setState(() => _stepDone = true);
  }

  void _enter(int index) {
    _speaker.stop();
    _index = index;
    _stepDone = true; // 没有动画的步骤立刻就算"演完了"
    _scene.become(_starts[index]);
    _play();
  }

  void _play() {
    final ExperimentStep step = _steps[_index];
    _clock.stop();
    _speaker.say(
      text: step.text,
      clipKey: 'assets/content/${widget.topic.slug}/audio/${step.audio}',
    );

    final Object? broken = _errors[_index];
    if (broken != null || step.bricks.isEmpty) {
      _timeline = SceneTimeline.empty;
      _span = Duration.zero;
      return;
    }
    _timeline = buildStepTimeline(step.bricks, _scene);
    _span = _timeline.duration;
    if (_span == Duration.zero) {
      _timeline.settle();
      return;
    }
    _stepDone = false;
    _clock.duration = _span;
    _clock.forward(from: 0);
  }

  void _next() {
    if (_index < _steps.length - 1) {
      setState(() => _enter(_index + 1));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// 记一笔:问"你看到了什么",挑一个现象,拍不拍照都行。
  Future<void> _record() async {
    final ExperimentStep step = _steps[_index];
    final JournalEntry? entry = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusCard)),
      ),
      builder: (BuildContext ctx) => _RecordSheet(
        options: _exp.recordOptions,
        taker: _photo,
        makeEntry: (String optionId, String optionLabel, String? photoPath) => JournalEntry(
          id: '${widget.topic.slug}-${DateTime.now().millisecondsSinceEpoch}',
          slug: widget.topic.slug,
          title: widget.topic.title,
          stepIndex: _index,
          stepText: step.text,
          optionId: optionId,
          optionLabel: optionLabel,
          photoPath: photoPath,
          at: DateTime.now(),
        ),
      ),
    );
    if (entry == null || !mounted) return;

    await JournalScope.of(context).add(entry);
    if (!mounted) return;
    setState(() => _recorded.putIfAbsent(_index, () => <JournalEntry>[]).add(entry));
  }

  @override
  Widget build(BuildContext context) {
    final ExperimentStep step = _steps[_index];
    final List<JournalEntry> here = _recorded[_index] ?? const <JournalEntry>[];
    final bool broken = _errors[_index] != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: DesignTokens.gapS),
              StepDots(index: _index, total: _steps.length, accent: DesignTokens.skyBlue),
              const SizedBox(height: DesignTokens.gapS),
              if (_hasScene && !broken) ...<Widget>[
                SceneFrame(state: _scene),
                const SizedBox(height: DesignTokens.gap),
              ],
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SpeechBubble(text: step.text, talking: !_stepDone),
                        if (step.record) ...<Widget>[
                          const SizedBox(height: DesignTokens.gap),
                          _RecordCard(count: here.length, labels: here, onTap: _record),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              StepControls(
                keys: _keys,
                canBack: _index > 0,
                canNext: _stepDone,
                nextLabel: _index == _steps.length - 1 ? '做完了' : '下一步',
                replayLabel: '再听一遍',
                accent: DesignTokens.skyBlue,
                onBack: () => setState(() => _enter(_index - 1)),
                onReplay: () => setState(_play),
                onNext: _next,
              ),
              const SizedBox(height: DesignTokens.gap),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「这一步要记下来」的那张卡。记完了就把记到的东西列出来。
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.count, required this.labels, required this.onTap});

  final int count;
  final List<JournalEntry> labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: const Color(0xFFE8F6FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '📷 这一步要记下来',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: DesignTokens.skyBlueDeep,
            ),
          ),
          const SizedBox(height: DesignTokens.gapS),
          if (count == 0)
            const Text(
              '做完了,把你看到的样子记下来吧',
              style: TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
            )
          else
            for (final JournalEntry e in labels)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '已记:${e.optionLabel}${e.photoPath != null ? '(带照片)' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.skyBlueDeep,
                  ),
                ),
              ),
          const SizedBox(height: DesignTokens.gapS),
          FilledButton.icon(
            key: const Key('experiment.record'),
            onPressed: onTap,
            icon: const Icon(Icons.edit_rounded, size: 22),
            label: const Text('记一笔'),
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.skyBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              textStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                  .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 记一笔的弹层:挑现象 + 可选拍照。
class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.options,
    required this.taker,
    required this.makeEntry,
  });

  final List<RecordOption> options;
  final PhotoTaker taker;
  final JournalEntry Function(String optionId, String optionLabel, String? photoPath)
      makeEntry;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  String? _optionId;
  String? _photoPath;
  bool _taking = false;
  bool _triedShot = false;

  @override
  Widget build(BuildContext context) {
    final RecordOption? chosen = widget.options
        .cast<RecordOption?>()
        .firstWhere((RecordOption? o) => o!.id == _optionId, orElse: () => null);

    return Padding(
      padding: EdgeInsets.only(
        left: DesignTokens.pagePadding,
        right: DesignTokens.pagePadding,
        top: DesignTokens.gapL,
        bottom: DesignTokens.pagePadding + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '你看到了什么?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: DesignTokens.gap),
          Wrap(
            spacing: DesignTokens.gapS,
            runSpacing: DesignTokens.gapS,
            children: <Widget>[
              for (final RecordOption o in widget.options)
                _OptionChip(
                  option: o,
                  selected: o.id == _optionId,
                  onTap: () => setState(() => _optionId = o.id),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.gap),
          OutlinedButton.icon(
            key: const Key('record.photo'),
            onPressed: _taking ? null : _takePhoto,
            icon: const Icon(Icons.photo_camera_rounded, size: 22),
            label: Text(_photoLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: DesignTokens.ink,
              side: const BorderSide(color: DesignTokens.outline, width: DesignTokens.borderWidth),
              minimumSize: const Size(0, 52),
              textStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.gap),
          FilledButton(
            key: const Key('record.save'),
            onPressed: chosen == null
                ? null
                : () => Navigator.of(context).pop(
                      widget.makeEntry(chosen.id, chosen.label, _photoPath),
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.leafGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: DesignTokens.leafGreen.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size(0, 56),
              textStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                  .copyWith(fontSize: 18, fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              ),
            ),
            child: const Text('存进实验册'),
          ),
          const SizedBox(height: DesignTokens.gapS),
          const Text(
            '不挑现象、不拍照也存不了哦 —— 至少要说出你看到了什么',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }

  String get _photoLabel {
    if (_taking) return '正在打开相机…';
    if (_photoPath != null) return '照片拍好了,再拍一张';
    if (_triedShot) return '没拍成(没相机或没给权限),再试一次';
    return '拍张照片(可以不拍)';
  }

  Future<void> _takePhoto() async {
    setState(() => _taking = true);
    final String? path = await widget.taker.take();
    if (!mounted) return;
    setState(() {
      _taking = false;
      _triedShot = true;
      if (path != null) _photoPath = path;
    });
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.option, required this.selected, required this.onTap});

  final RecordOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DesignTokens.skyBlue : DesignTokens.card,
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
          border: Border.all(color: DesignTokens.outline, width: DesignTokens.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (option.emoji != null) ...<Widget>[
              Text(option.emoji!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
            ],
            Text(
              option.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : DesignTokens.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
