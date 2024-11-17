import 'dart:async' show Future, scheduleMicrotask;
import 'dart:ui' as ui show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheImageProvider extends ImageProvider<CacheImageProvider> {
  static BaseCacheManager defaultCacheManager = DefaultCacheManager();

  final String imageLink;

  final String? cacheKey;

  final double scale;

  final bool needSign;

  CacheImageProvider.link(this.imageLink, {this.cacheKey, this.scale = 1.0})
      : needSign = false;

  CacheImageProvider.sign(this.imageLink, {this.cacheKey, this.scale = 1.0})
      : needSign = true;

  @override
  Future<CacheImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CacheImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      CacheImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: requestImageAsync(key, decode),
      scale: scale,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CacheImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> requestImageAsync(
    CacheImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    BaseCacheManager manager = defaultCacheManager;
    String cacheKey = key.cacheKey ?? key.imageLink;

    try {
      FileInfo? cacheFile = await manager.getFileFromCache(cacheKey);
      if (cacheFile != null) {
        return readCacheFile(cacheFile, decode);
      }

      String imageUri = "";
      if (key.needSign) {
        imageUri = "signLink";
      } else {
        imageUri = key.imageLink;
      }

      cacheFile = await manager.downloadFile(imageUri, key: cacheKey);
      return readCacheFile(cacheFile, decode);
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  Future<ui.Codec> readCacheFile(
      FileInfo cacheFile, ImageDecoderCallback decode) async {
    final stream = cacheFile.file.openRead();
    final bytes = await readStreamToBytes(stream);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  Future<Uint8List> readStreamToBytes(Stream<List<int>> stream) async {
    final byteList = <int>[];
    await for (var chunk in stream) {
      byteList.addAll(chunk);
    }
    return Uint8List.fromList(byteList);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CacheImageProvider &&
        other.imageLink == imageLink &&
        other.cacheKey == cacheKey &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? imageLink, scale);
}
