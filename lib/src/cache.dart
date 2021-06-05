import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'file_system/file_system.dart';
import 'file_system/file_system_disk.dart';
import 'file_system/file_system_memory.dart';

class CacheElement {
  final String id;
  final String path;
  final int checksum;
  final int bytes;
  final DateTime createdAt;
  final DateTime expiredAt;

  CacheElement(this.id, this.path, this.checksum, this.bytes, this.createdAt,
      this.expiredAt);

  factory CacheElement.fromJson(Map<String, dynamic> json) => CacheElement(
        json['id'],
        json['path'],
        json['checksum'],
        json['bytes'],
        DateTime.parse(json['createdAt']),
        DateTime.parse(json['expiredAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'checksum': checksum,
        'bytes': bytes,
        'createdAt': createdAt.toIso8601String(),
        'expiredAt': expiredAt.toIso8601String(),
      };

  Map<String, dynamic> toEncodable() => toJson();
}

class CacheConfig {
  final Duration maxAge;
  final int maxBytes;
  final int maxFiles;
  final FileSystem fileSystem;
  final bool temporary;

  CacheConfig({
    this.maxAge = const Duration(days: 10),
    this.maxBytes = 100000,
    this.maxFiles = 1000,
    this.temporary = true,
    FileSystem? fs,
  }) : this.fileSystem = fs ??
            (kIsWeb
                ? FileSystemMemory('image-cache')
                : FileSystemDisk('image-cache'));
}

class CacheManager {
  CacheManager({CacheConfig? config}) : this.config = config ?? CacheConfig();

  final CacheConfig config;

  final _metadata = Map<String, CacheElement>();
  final _printErrors = true;

  Future _dumpMetadata() async {
    _filterMetadata();
    final file = await config.fileSystem.getFile('metadata.json');
    await file.writeAsString(jsonEncode(_metadata));
  }

  Future _filterMetadata() async {
    final toDelete = _metadata.entries
        .where((it) => it.value.expiredAt.isBefore(DateTime.now()));
    final futures = toDelete.map((e) async {
      final file = await config.fileSystem.getFile(e.value.id);
      file.delete();
      _metadata.remove(e.key);
    });
    NetworkImage;
    await Future.wait(futures);
  }

  Future<Uint8List?> get(String id) async {
    try {
      final element = _metadata[id];
      if (element != null) {
        final file = await config.fileSystem.getFile(id);
        final data = await file.readAsBytes();
        if (getCrc32(data) == element.checksum) {
          return data;
        }
      }
    } catch (e) {
      if (_printErrors) print(e);
    }
  }

  Future<bool> has(String id) async {
    try {
      final element = _metadata[id];
      if (element != null) {
        return true;
      }
    } catch (e) {
      if (_printErrors) print(e);
    }
    return false;
  }

  Future<bool> save(String id, Uint8List data) async {
    try {
      final file = await config.fileSystem.getFile(id);
      file.writeAsBytes(data);
      _metadata[id] = CacheElement(
        id,
        file.path,
        getCrc32(data),
        data.lengthInBytes,
        DateTime.now(),
        DateTime.now().add(config.maxAge),
      );
      await _dumpMetadata();

      return true;
    } catch (e) {
      if (_printErrors) print(e);
      return false;
    }
  }

  Future<bool> evict(String id) async {
    try {
      final file = await config.fileSystem.getFile(id);
      file.delete();
      _metadata.remove(id);
      await _dumpMetadata();

      return true;
    } catch (e) {
      if (_printErrors) print(e);
      return false;
    }
  }
}
