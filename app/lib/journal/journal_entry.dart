import 'dart:convert';

/// 实验册里的一笔:哪次实验、第几步、看到了什么、有没有照片。
///
/// 存的是**观察到的东西**(现象选项 + 照片),不是对错 —— 这个年龄段重点在
/// "我看见了吗、我说得出来吗",不是判卷。
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.slug,
    required this.title,
    required this.stepIndex,
    required this.stepText,
    required this.optionId,
    required this.optionLabel,
    required this.at,
    this.photoPath,
  });

  final String id;
  final String slug;
  final String title;

  /// 第几步记的(从 0 数)
  final int stepIndex;
  final String stepText;

  final String optionId;
  final String optionLabel;

  /// 照片相对 App 文档目录的路径(`photos/xxx.jpg`)。没拍就是 null。
  final String? photoPath;

  final DateTime at;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        stepIndex: json['stepIndex'] as int,
        stepText: json['stepText'] as String,
        optionId: json['optionId'] as String,
        optionLabel: json['optionLabel'] as String,
        photoPath: json['photoPath'] as String?,
        at: DateTime.parse(json['at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'slug': slug,
        'title': title,
        'stepIndex': stepIndex,
        'stepText': stepText,
        'optionId': optionId,
        'optionLabel': optionLabel,
        'photoPath': photoPath,
        'at': at.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static JournalEntry decode(String raw) =>
      JournalEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
