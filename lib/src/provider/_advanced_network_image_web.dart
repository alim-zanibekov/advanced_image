import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

import '../cache.dart';
import 'image_provider.dart' as image_provider;

const isCanvasKit =
    const bool.fromEnvironment('FLUTTER_WEB_USE_SKIA', defaultValue: false);

class AdvancedNetworkImage
    extends ImageProvider<image_provider.AdvancedNetworkImage>
    implements image_provider.AdvancedNetworkImage {
  static final _defaultHttpClient = Dio();

  AdvancedNetworkImage(
    this.url, {
    this.scale = 1.0,
    this.headers,
    CacheManager? cacheManager,
    RetryOptions? retryOptions,
    Dio? dio,
  })  : this.cacheManager = cacheManager ?? CacheManager(),
        this._httpClient = dio ?? _defaultHttpClient;

  final CacheManager cacheManager;

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  Dio _httpClient;

  final _cancelToken = CancelToken();

  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _cancelToken.cancel();
  }

  @override
  Future<AdvancedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AdvancedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter load(
      image_provider.AdvancedNetworkImage key, DecoderCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      chunkEvents: chunkEvents.stream,
      codec: _loadAsync(key as AdvancedNetworkImage, decode, chunkEvents),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: _imageStreamInformationCollector(key),
    );
  }

  InformationCollector? _imageStreamInformationCollector(
      image_provider.AdvancedNetworkImage key) {
    InformationCollector? collector;
    assert(() {
      collector = () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<AdvancedNetworkImage>('Image provider', this),
          DiagnosticsProperty<AdvancedNetworkImage>(
              'Image key', key as AdvancedNetworkImage),
        ];
      };
      return true;
    }());
    return collector;
  }

  Future<ui.Codec> _loadAsync(AdvancedNetworkImage key, DecoderCallback decode,
      StreamController<ImageChunkEvent> chunkEvents) async {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key.url);
    if (_cancelled) {
      throw Exception('AdvancedNetworkImage operation cancelled');
    }

    if (isCanvasKit) {
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

      return ui.instantiateImageCodec(bytes);
    } else {
      final result = ui.webOnlyInstantiateImageCodecFromUrl(// ignore: undefined_function
        resolved,
        chunkCallback: (int bytes, int total) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: bytes,
            expectedTotalBytes: total,
          ));
        },
      );
      return result;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AdvancedNetworkImage &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => ui.hashValues(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: $scale)';
}
