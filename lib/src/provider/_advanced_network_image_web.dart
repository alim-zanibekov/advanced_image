import 'dart:async';
import 'dart:ui' as ui;

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
    CacheManager? cacheManager,
    RetryOptions? retryOptions,
  }) : this.cacheManager = cacheManager ?? CacheManager();

  final CacheManager cacheManager;

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  CancelableOperation<ui.Codec>? _imageFuture;

  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _imageFuture?.cancel();
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
      StreamController<ImageChunkEvent> chunkEvents) {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key.url);
    if (_cancelled) {
      throw Exception('AdvancedNetworkImage operation cancelled');
    }

    final result = CancelableOperation.fromFuture(
      ui.webOnlyInstantiateImageCodecFromUrl(
          // ignore: undefined_function
          resolved, chunkCallback: (int bytes, int total) {
        chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: bytes, expectedTotalBytes: total));
      }) as Future<ui.Codec>, // ignore: undefined_function
    );

    _imageFuture = result;

    return result.value; // ignore: undefined_function
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
