import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, hashValues;

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

import '../cache.dart';
import 'image_provider.dart' as image_provider;

class AdvancedNetworkImage
    extends ImageProvider<image_provider.AdvancedNetworkImage>
    implements image_provider.AdvancedNetworkImage {
  AdvancedNetworkImage(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.retryOptions = const RetryOptions(maxAttempts: 5),
    CacheManager? cacheManager,
  }) : this.cacheManager = cacheManager ?? CacheManager();

  final CacheManager cacheManager;

  final RetryOptions? retryOptions;

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  CancelableOperation<HttpClientResponse>? _imageFuture;

  bool _cancelled = false;

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

  static final HttpClient _sharedHttpClient = HttpClient()
    ..autoUncompress = false;

  static HttpClient get _httpClient {
    HttpClient client = _sharedHttpClient;
    assert(() {
      if (debugNetworkImageHttpClientProvider != null)
        client = debugNetworkImageHttpClientProvider!();
      return true;
    }());
    return client;
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _imageFuture?.cancel();
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

      final loadImage = () async {
        final HttpClientRequest request = await _httpClient.getUrl(resolved);

        headers?.forEach((String name, String value) {
          request.headers.add(name, value);
        });

        return request.close();
      };

      final imageFuture = CancelableOperation.fromFuture(
          retryOptions?.retry(loadImage) ?? loadImage());

      _imageFuture = imageFuture;

      if (_cancelled) {
        throw Exception('AdvancedNetworkImage operation cancelled');
      }

      final HttpClientResponse response = await imageFuture.value;

      if (response.statusCode != HttpStatus.ok) {
        throw NetworkImageLoadException(
            statusCode: response.statusCode, uri: resolved);
      }

      final Uint8List bytes = await consolidateHttpClientResponseBytes(
        response,
        onBytesReceived: (int cumulative, int? total) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: cumulative,
            expectedTotalBytes: total,
          ));
        },
      );
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
