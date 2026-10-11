import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// App 自己的目录。启动时填一次,之后同步取用 —— 界面里要拿照片的绝对路径,
/// 总不能每画一帧都去 await 一次。
class AppPaths {
  const AppPaths._();

  static String? documentsDir;

  static bool get ready => documentsDir != null;

  /// 把实验册里存的相对路径(`photos/xxx.jpg`)还原成绝对路径。
  static String? resolve(String relative) =>
      documentsDir == null ? null : '$documentsDir/$relative';
}

/// 拍一张照片存下来。
///
/// 拍不了的情况太多了(设备没相机、没给权限、小妍按了返回),所以返回 null 是
/// **正常路径**不是错误:实验照样能记,只是这一笔没有照片。
abstract class PhotoTaker {
  /// 成功返回相对 App 文档目录的路径(如 `photos/1712345.jpg`),失败返回 null。
  Future<String?> take();
}

/// 真机上用的:调系统相机,拷进 App 目录。
class CameraPhotoTaker implements PhotoTaker {
  const CameraPhotoTaker();

  @override
  Future<String?> take() async {
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600, // 记个现象而已,不用原图,省得占小妍的存储
        imageQuality: 85,
      );
      if (shot == null) return null;

      final Directory dir = Directory('${AppPaths.documentsDir}/photos');
      await dir.create(recursive: true);
      final String name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy('${dir.path}/$name');
      return 'photos/$name';
    } catch (_) {
      // 没相机 / 没权限 / 用户取消 —— 在页面上一律表现成"这次没拍成"
      return null;
    }
  }
}

/// 测试用:直接给一个写死的路径(或者 null 表示没拍)。
class StubPhotoTaker implements PhotoTaker {
  StubPhotoTaker({this.path});

  final String? path;

  @override
  Future<String?> take() async => path;
}
