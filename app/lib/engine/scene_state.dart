/// 学环节的"世界状态"—— 屏幕上此刻摆着什么、杯里的水到哪、鸡蛋在第几层。
///
/// **这是整个学引擎最要紧的一条:状态跨步骤累积,不是每步重画一遍。**
/// 冒烟包里第 3 步只调了 `shared.highlight`、第 4 步只调了 `science.pour`,
/// 可第 2 步倒进去的那杯水必须还在屏幕上 —— 所以积木是**改这个对象的动作**,
/// 不是各自画各自的一张图。少了这条,第 3 步一进去水就没了。
///
/// 纯数据,不认识画布也不认识时间;画它的是 `scene_painter.dart`,
/// 改它的是 `lib/bricks/` 下那些积木。字段就是这个实验需要用到的全部词汇量,
/// 以后新积木要用新词,往这里加。
class SceneState {
  SceneState();

  /// 台上摆着的东西。`shared.scene` 决定摆哪几样。
  /// 认识的名字:bench(实验台)/ cup(杯子)/ egg(鸡蛋)。
  final Set<String> objects = <String>{};

  /// 杯里的水,液面高度占杯子内高的比例(0 = 空,1 = 满)。
  double liquidLevel = 0;

  /// 水里化没化盐。化了就颜色发一点青白、液面看着更"稠"。
  bool salted = false;

  /// 鸡蛋在不在杯子里。不在的时候搁在台子上。
  bool eggInCup = false;

  /// 鸡蛋在杯子里的相对高度:0 = 贴着杯底,1 = 浮在水面上。
  double eggLevel = 0;

  /// 杯底那堆没化开的盐,0..1。倒盐的时候涨起来,搅完消失。
  double saltPile = 0;

  /// 正往杯里倒东西 —— 决定要不要画那道从杯口落下去的流。
  /// 不画这道流的话,倒盐是看不出来的:杯子底的盐堆正好被鸡蛋挡个严实。
  bool pouring = false;

  /// 倒的是什么:`salt` 或 `water`。空串表示没在倒。
  String pourItem = '';

  /// 正在搅拌 —— 决定要不要画那根勺子。
  bool stirring = false;

  /// 搅拌棒转到哪个角度(弧度)。
  double stirAngle = 0;

  /// 高亮的对象与它旁边那句短标签。
  String? highlightTarget;
  String? highlightLabel;

  // ── 数学:数一数用的点子(相当于小棒)────────────────────────────
  // 数学包不想把"3 + 2"写成一行算式,而是让点子一颗一颗冒出来。
  // 左组 a 个、右组 b 个,加号夹在中间;`join` 一推,右组滑过去并成一群。

  /// 左边一组几个点子。
  int counterA = 0;

  /// 右边一组几个点子。0 表示只有一组(单纯的"数一数")。
  int counterB = 0;

  /// 已经冒出来几颗(带小数,画的时候按整数取)。一颗一颗冒就是它在涨。
  double counterShown = 0;

  /// 两组并到一起的程度:0 = 分开摆着,1 = 并成一排(加号同时淡出)。
  double counterJoin = 0;

  /// 复制一份。用来在开启一步之前存个档 —— 「上一步」「重播」都要靠它回到当时的画面。
  SceneState clone() {
    return SceneState()
      ..objects.addAll(objects)
      ..liquidLevel = liquidLevel
      ..salted = salted
      ..eggInCup = eggInCup
      ..eggLevel = eggLevel
      ..saltPile = saltPile
      ..pouring = pouring
      ..pourItem = pourItem
      ..stirring = stirring
      ..stirAngle = stirAngle
      ..highlightTarget = highlightTarget
      ..highlightLabel = highlightLabel
      ..counterA = counterA
      ..counterB = counterB
      ..counterShown = counterShown
      ..counterJoin = counterJoin;
  }

  /// 就地吃下另一份状态。执行器在每一步开始时用它把世界倒回存档。
  void become(SceneState other) {
    objects
      ..clear()
      ..addAll(other.objects);
    liquidLevel = other.liquidLevel;
    salted = other.salted;
    eggInCup = other.eggInCup;
    eggLevel = other.eggLevel;
    saltPile = other.saltPile;
    pouring = other.pouring;
    pourItem = other.pourItem;
    stirring = other.stirring;
    stirAngle = other.stirAngle;
    highlightTarget = other.highlightTarget;
    highlightLabel = other.highlightLabel;
    counterA = other.counterA;
    counterB = other.counterB;
    counterShown = other.counterShown;
    counterJoin = other.counterJoin;
  }
}
