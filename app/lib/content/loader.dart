import 'package:flutter/services.dart';

import 'models.dart';

/// 内容包仓库:从打包进 App 的资源里把 `assets/content/<slug>/topic.json` 找出来读成 [Topic]。
///
/// 包是扫描出来的,不是硬编码清单 —— 加一个内容包只要放目录 + 在 pubspec.yaml
/// 的 assets 里声明两行,这里不用改。
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static final RegExp _topicKey = RegExp(r'^assets/content/([a-z0-9][a-z0-9-]*)/topic\.json$');

  static String _keyOf(String slug) => 'assets/content/$slug/topic.json';

  /// 扫出所有内容包的 slug,按名字排序(列表顺序稳定)。
  Future<List<String>> listSlugs() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final List<String> slugs = manifest
        .listAssets()
        .map((String key) => _topicKey.firstMatch(key)?.group(1))
        .whereType<String>()
        .toList();
    return slugs..sort();
  }

  Future<Topic> load(String slug) async {
    final String key = _keyOf(slug);
    final String source;
    try {
      source = await _bundle.loadString(key);
    } catch (_) {
      // 这里 `catch` 不挑类型是有意的:读不到资源时 Flutter 抛的是 FlutterError,
      // 它继承 Error 而不是 Exception,写成 `on Exception` 会漏掉。
      // 作用域里只有这一次 loadString,任何异常都是"这个包没打进 App"。
      throw ContentFormatException('读不到 $key —— 这个包在 pubspec.yaml 的 assets 里声明了吗?');
    }
    return Topic.parse(source, origin: slug);
  }

  Future<List<Topic>> loadAll() async {
    final List<String> slugs = await listSlugs();
    return Future.wait(slugs.map(load));
  }

  /// 按板块取包:数学乐园只要 math,科学小实验只要 science。
  Future<List<Topic>> loadByKind(TopicKind kind) async {
    final List<Topic> all = await loadAll();
    return all.where((Topic t) => t.kind == kind).toList();
  }
}
