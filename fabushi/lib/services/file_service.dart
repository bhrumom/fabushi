import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'abstract_file_service.dart';

export 'file_service_io.dart' if (dart.library.html) 'file_service_web.dart';

// 这个文件只是一个导出文件，实际实现在file_service_io.dart和file_service_web.dart中
