import 'loader.dart';
import 'models.dart';

/// 读不出来的包。一个包坏掉不该拖垮整页,更不该让 App 起不来 ——
/// 记下来,在列表里明说,其它包照常用。
class BrokenPack {
  const BrokenPack({required this.slug, required this.message});

  final String slug;
  final String message;
}

/// 内容库:App 启动时把所有内容包读一遍,之后界面全部同步取用。
///
/// 内容包是随 App 打包的静态资源,读一次就够;放进启动流程还能顺手把坏包
/// 收集起来,免得每次翻列表都去碰一次 IO。
class ContentLibrary {
  const ContentLibrary({required this.topics, required this.broken});

  final List<Topic> topics;
  final List<BrokenPack> broken;

  static const ContentLibrary empty = ContentLibrary(topics: <Topic>[], broken: <BrokenPack>[]);

  List<Topic> byKind(TopicKind kind) =>
      topics.where((Topic t) => t.kind == kind).toList(growable: false);

  /// 扫全部内容包。读不出/解析不了的进 [broken],不抛异常。
  static Future<ContentLibrary> load({ContentRepository? repository}) async {
    final ContentRepository repo = repository ?? ContentRepository();
    final List<Topic> topics = <Topic>[];
    final List<BrokenPack> broken = <BrokenPack>[];

    for (final String slug in await repo.listSlugs()) {
      try {
        topics.add(await repo.load(slug));
      } on ContentFormatException catch (e) {
        broken.add(BrokenPack(slug: slug, message: e.message));
      }
    }
    return ContentLibrary(topics: topics, broken: broken);
  }
}
