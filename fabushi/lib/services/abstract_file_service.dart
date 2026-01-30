import 'package:file_picker/file_picker.dart';

abstract class AbstractFileService {
  Future<List<PlatformFile>> pickFiles();
  Future<void> releaseFiles(List<PlatformFile> files);
}
