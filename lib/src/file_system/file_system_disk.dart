import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'file_system.dart';

class FileSystemDisk implements FileSystem {
  final Future<Directory> _fileDir;
  final String _cacheKey;

  FileSystemDisk(String? cacheKey)
      : _cacheKey = cacheKey ?? 'cache',
        _fileDir = _createDirectory(cacheKey ?? 'cache');

  static Future<Directory> _createDirectory(String key) async {
    var baseDir = await getTemporaryDirectory();
    var path = join(baseDir.path, key);

    var fs = const LocalFileSystem();
    var directory = fs.directory((path));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> getFile(String name) async {
    var directory = (await _fileDir);
    if (!(await directory.exists())) {
      await _createDirectory(_cacheKey);
    }
    return directory.childFile(name);
  }
}
