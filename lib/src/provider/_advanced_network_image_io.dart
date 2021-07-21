import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, hashValues;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

import '../cache.dart';
import 'image_provider.dart' as image_provider;

class AdvancedNetworkImage
    extends ImageProvider<image_provider.AdvancedNetworkImage>
    implements image_provider.AdvancedNetworkImage {
  static final _defaultHttpClient = Dio();

  AdvancedNetworkImage(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.retryOptions = const RetryOptions(maxAttempts: 5),
    CacheManager? cacheManager,
    Dio? dio,
  })  : this.cacheManager = cacheManager ?? CacheManager(),
        this._httpClient = dio ?? _defaultHttpClient;

  final CacheManager cacheManager;

  final RetryOptions? retryOptions;

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  bool _cancelled = false;

  Dio _httpClient;

  final _cancelToken = CancelToken();

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(
    image_provider.AdvancedNetworkImage key,
    DecoderCallback decode,
  ) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as AdvancedNetworkImage, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<image_provider.AdvancedNetworkImage>(
              'Image key', key),
        ];
      },
    );
  }

  @override
  void cancel() {
    _cancelled = true;
    _cancelToken.cancel();
  }

  Future<ui.Codec> _loadAsync(
    AdvancedNetworkImage key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async {
    try {
      assert(key == this);
      String uId = key.url.hashCode.toString();

      final cached = await cacheManager.get(uId);

      if (cached != null) {
        return decode(cached);
      }

      final Uri resolved = Uri.base.resolve(key.url);

      if (_cancelled) {
        throw Exception('AdvancedNetworkImage operation cancelled');
      }

      Response<Uint8List> response = await _httpClient.getUri(resolved,
          options: Options(headers: headers, responseType: ResponseType.bytes),
          cancelToken: _cancelToken, onReceiveProgress: (int count, int total) {
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: count,
          expectedTotalBytes: total,
        ));
      });

      final bytes = response.data;

      if (response.statusCode != HttpStatus.ok || bytes == null) {
        throw NetworkImageLoadException(
            statusCode: response.statusCode ?? 0, uri: resolved);
      }

      if (bytes.lengthInBytes == 0)
        throw Exception('AdvancedNetworkImage is an empty file: $resolved');

      cacheManager.save(uId, bytes);
      return decode(bytes);
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance!.imageCache!.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is AdvancedNetworkImage &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => ui.hashValues(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'AdvancedNetworkImage')}("$url", scale: $scale)';
}
