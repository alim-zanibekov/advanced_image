import 'package:file/file.dart';

abstract class FileSystem {
  Future<File> getFile(String name);
}
