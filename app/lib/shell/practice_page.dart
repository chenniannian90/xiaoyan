import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/speaker.dart';
import '../content/models.dart';
import '../practice/templates.dart';
import '../theme/design_tokens.dart';
import '../wrong/wrong_book.dart';
import '../wrong/wrong_scope.dart';
import 'learn_page.dart';
import 'practice_result_page.dart';
import 'widgets/step_widgets.dart';


/// 练环节:一道一道做,做对得星,做错不罚。
///
/// 设计文档 §4 的规矩都落在这页:
/// - 一次做对 → ⭐ + 随机夸奖 + 彩带;
/// - 做错 → 轻抖动 + 亮提示,可以再试(不锁题、不扣分、不骂人);
/// - 连错 3 次 → 「再看一遍动画」送回学的对应步骤,看完回来还是这道题;
/// - 错过的题自动进错题本(重练做对才翻身)。
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.topic,
    this.speaker,
    this.only,
  });

  final Topic topic;

  /// 测试塞假的进来(音频插件在测试环境里跑不起来)。
  final Speaker? speaker;

  /// 只练指定的几题(错题重练用)。null = 整个包从头练。
  final Set<int>? only;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with SingleTickerProviderStateMixin {
  late final Speaker _speaker = widget.speaker ?? PhoneSpeaker();

  /// 要做的题(下标)。错题重练时是挑出来的那几道。
  late final List<int> _items = List<int>.generate(
    widget.topic.practice!.items.length,
    (int i) => i,
  ).where((int i) => widget.only?.contains(i) ?? true).toList();

  int _index = 0; // 走到 _items 的第几个
  int _stars = 0; // 一次做对的题数
  int _misses = 0; // 这道题连错几次
  bool _wrongTried = false; // 这道题是不是错过至少一次(错过就不再得星)

  late MathQuestion _question = _buildQuestion();

  /// 答对的彩带还飘着吗(飘完自动去下一题)。
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  int get _itemIndex => _items[_index];

  void _ask() {
    _misses = 0;
    _wrongTried = false;
    _speaker.say(text: '${_question.ask} 挑一个数字吧。');
  }

  Future<void> _pick(int value) async {
    if (_celebrating) return; // 彩带飘着的时候别重复记
    if (value == _question.answer) {
      await _correct();
    } else {
      _misses++;
      _wrongTried = true;
      await WrongBookScope.of(context).recordWrong(
        WrongAnswer(
          slug: widget.topic.slug,
          itemIndex: _itemIndex,
          topicTitle: widget.topic.title,
          prompt: _question.ask,
          wrongCount: 1, // store 会把旧档的次数叠上来
          lastAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _speaker.say(text: _misses >= 3 ? '没关系,我们看一遍动画就明白了。' : '再想一想,你可以的。');
      setState(() => _shakeKey++); // 抖一下选错的那颗
    }
  }

  Future<void> _correct() async {
    if (!_wrongTried) _stars++;
    // 答对就翻身 —— 错题本里要是记着这道题,现在它翻成「已会了」。
    // 重练一次就对也算会(不需要先错一次才翻身);没记过的题调 resolve 等于没发生。
    await WrongBookScope.of(context).resolve(widget.topic.slug, _itemIndex);
    if (!mounted) return;
    _speaker.say(text: _praise());
    setState(() => _celebrating = true);
    // 彩带飘 1.6 秒再走,让「答对了」这件事有落地的感觉
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    _next();
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() {
        _index++;
        _question = _buildQuestion();
        _celebrating = false;
      });
      _ask();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PracticeResultPage(
            topic: widget.topic,
            stars: _stars,
            total: _items.length,
          ),
        ),
      );
    }
  }

  MathQuestion _buildQuestion() {
    final PracticeItem item = widget.topic.practice!.items[_itemIndex];
    return templateNamed(item.template).build(item);
  }

  int _shakeKey = 0;

  static const List<String> _praises = <String>[
    '答对啦,你真棒!',
    '没错,就是这样!',
    '太厉害了,数得又对又快!',
  ];
  String _praise() => _praises[_index % _praises.length];

  /// 连错 3 次:送回学的最后一步(讲「合起来」的那步),看完回来接着做。
  void _relearn() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<bool>(
            builder: (_) => LearnPage(topic: widget.topic, startIndex: _relearnStep),
          ),
        )
        .then((_) {
      _misses = 0; // 回来重新给 3 次机会
      if (mounted) _ask();
    });
  }

  /// 学环节里讲「合起来」的那步:最后一块带 join 的积木在哪步就是哪步,
  /// 没有就回第 1 步。
  int get _relearnStep {
    final List<LearnStep> steps = widget.topic.learn.steps;
    for (int i = steps.length - 1; i >= 0; i--) {
      if (steps[i].bricks.any(
        (BrickCall b) => b.params['join'] == true || b.brick.startsWith('math.'),
      )) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: DesignTokens.gapS),
                  StepDots(
                    index: _index,
                    total: _items.length,
                    accent: DesignTokens.leafGreen,
                    noun: '题',
                  ),
                  const SizedBox(height: DesignTokens.gapS),
                  _FaceCard(child: _question.face),
                  const SizedBox(height: DesignTokens.gap),
                  SpeechBubble(text: _question.ask, talking: false),
                  if (_misses > 0 && _question.hint != null) ...<Widget>[
                    const SizedBox(height: DesignTokens.gapS),
                    Text(
                      '💡 ${_question.hint!}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: DesignTokens.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_misses >= 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DesignTokens.gapS),
                      child: FilledButton.icon(
                        key: const Key('practice.relearn'),
                        onPressed: _relearn,
                        icon: const Icon(Icons.movie_rounded, size: 24),
                        label: const Text('再看一遍动画'),
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignTokens.sunnyYellow,
                          foregroundColor: DesignTokens.ink,
                          minimumSize: const Size(0, 54),
                          textStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                              .copyWith(fontSize: 17, fontWeight: FontWeight.w900),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                          ),
                        ),
                      ),
                    ),
                  _Choices(
                    choices: _question.choices,
                    onPick: _pick,
                    shakeKey: _shakeKey,
                    enabled: !_celebrating,
                  ),
                  const SizedBox(height: DesignTokens.gap),
                ],
              ),
            ),
            if (_celebrating) const _Confetti(),
          ],
        ),
      ),
    );
  }
}

/// 题面的框。跟 SceneFrame 一样的比例(1000:640),点子画笔是按它设计的。
class _FaceCard extends StatelessWidget {
  const _FaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF9E7),
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: DesignTokens.outline, width: DesignTokens.borderWidth),
          boxShadow: DesignTokens.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard - 2),
          child: child,
        ),
      ),
    );
  }
}

/// 数字选项。手指点得到(高 60),打错的那颗抖一下。
class _Choices extends StatelessWidget {
  const _Choices({
    required this.choices,
    required this.onPick,
    required this.shakeKey,
    required this.enabled,
  });

  final List<int> choices;
  final void Function(int) onPick;
  final int shakeKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < choices.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: DesignTokens.gap),
          Expanded(
            child: _ChoiceButton(
              value: choices[i],
              onTap: enabled ? () => onPick(choices[i]) : null,
              shakeKey: shakeKey,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  const _ChoiceButton({required this.value, required this.onTap, required this.shakeKey});

  final int value;
  final VoidCallback? onTap;
  final int shakeKey;

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_ChoiceButton old) {
    super.didUpdateWidget(old);
    // shakeKey 变了才抖 —— 而且只在「这是刚选的那颗」时。
    // 哪颗被选了页面没传来,那就抖全部:三颗一起抖 420ms,孩子看得懂哪次选错了,
    // 也比传一堆状态干净。真要精确到一颗,再加个 lastWrong 字段就行。
    if (widget.shakeKey != old.shakeKey && widget.shakeKey > 0) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dx = 10 * math.sin(_shake.value * 6 * math.pi) * (1 - _shake.value);
    return Transform.translate(
      offset: Offset(dx, 0),
      child: FilledButton(
        key: Key('practice.choice.${widget.value}'),
        onPressed: widget.onTap,
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.card,
          foregroundColor: DesignTokens.ink,
          disabledBackgroundColor: DesignTokens.card,
          side: const BorderSide(color: DesignTokens.outline, width: DesignTokens.borderWidth),
          minimumSize: const Size(0, 60),
          textStyle: (Theme.of(context).textTheme.displaySmall ?? const TextStyle())
              .copyWith(fontSize: 34, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
          ),
        ),
        child: Text('${widget.value}'),
      ),
    );
  }
}

/// 答对的彩带:从顶上撒下来的一把纸屑。位置全是算出来的(下标 + 相位),
/// 没有随机 —— 同一帧永远画成一样,截图比对才稳。
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fly,
        builder: (BuildContext context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(t: _fly.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.t});

  final double t;

  static const List<Color> _colors = <Color>[
    DesignTokens.leafGreen,
    DesignTokens.sunnyYellow,
    DesignTokens.skyBlue,
    Color(0xFFF49FBC),
    Color(0xFFFF8A65),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    for (int i = 0; i < 26; i++) {
      final double phase = (i * 0.137) % 1;
      final double fall = t + phase * 0.4;
      if (fall > 1.1) continue;
      final double x = size.width * ((i * 0.173 + 0.08) % 0.9) +
          16 * math.sin(fall * 5 + i);
      final double y = size.height * fall * 1.2 - 40;
      final double w = 10 + (i % 3) * 4;
      p.color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(fall * 7 + i);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
