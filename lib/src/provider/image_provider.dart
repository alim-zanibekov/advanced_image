import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:retry/retry.dart';

import '../cache.dart';
import '_advanced_network_image_io.dart'
    if (dart.library.html) '_advanced_network_image_web.dart'
    as advanced_network_image;

abstract class AdvancedNetworkImage
    extends ImageProvider<AdvancedNetworkImage> {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  factory AdvancedNetworkImage(String url,
          {double scale,
          Map<String, String>? headers,
          RetryOptions? retryOptions,
          CacheManager? cacheManager}) =
      advanced_network_image.AdvancedNetworkImage;

  /// The URL from which the image will be fetched.
  String get url;

  /// The scale to place in the [ImageInfo] object of the image.
  double get scale;

  /// Stop loading image.
  Future<void> cancel();

  /// The HTTP headers that will be used with [HttpClient.get] to fetch image from network.
  ///
  /// When running flutter on the web, headers are not used.
  Map<String, String>? get headers;

  @override
  ImageStreamCompleter load(AdvancedNetworkImage key, DecoderCallback decode);
}
