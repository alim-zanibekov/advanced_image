import 'package:file/file.dart' show File;
import 'package:file/memory.dart';

import 'file_system.dart';

class FileSystemMemory implements FileSystem {
  final _directory;

  FileSystemMemory(String? cacheKey)
      : _directory = MemoryFileSystem()
            .systemTempDirectory
            .createTemp(cacheKey ?? 'cache');

  @override
  Future<File> getFile(String name) async {
    return (await _directory).getFile(name);
  }
}
