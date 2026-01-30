// 创建一个通用文件类，用于在不同平台上表示文件
class CrossPlatformFile {
  final dynamic file; // 可以是File或html.File
  final String path;
  final String name;
  final int size;

  CrossPlatformFile({
    required this.file,
    required this.path,
    required this.name,
    required this.size,
  });

  // 添加lengthSync方法以兼容Web平台
  int lengthSync() {
    return size;
  }
}
