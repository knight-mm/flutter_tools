import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'cache_fade_widget.dart';
import 'cache_image_provider.dart';

class CacheImage extends StatefulWidget {
  final String imageLink;

  final String? cacheKey;

  final double? width;

  final double? height;

  final BoxFit? fit;

  final Color? color;

  final int? cacheWidth;

  final int? cacheHeight;

  final Animation<double>? opacity;

  final FilterQuality filterQuality;

  final BlendMode? colorBlendMode;

  final AlignmentGeometry alignment;

  final ImageRepeat repeat;

  final Rect? centerSlice;

  final bool matchTextDirection;

  final bool isAntiAlias;

  final ImageProvider image;

  CacheImage.link(
    this.imageLink, {
    super.key,
    this.cacheKey,
    double scale = 1.0,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.cacheWidth,
    this.cacheHeight,
    this.opacity,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.colorBlendMode,
  }) : image = ResizeImage.resizeIfNeeded(
            cacheWidth,
            cacheHeight,
            CacheImageProvider.link(imageLink,
                cacheKey: cacheKey, scale: scale));

  CacheImage.sign(
    this.imageLink, {
    super.key,
    this.cacheKey,
    double scale = 1.0,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.cacheWidth,
    this.cacheHeight,
    this.opacity,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.colorBlendMode,
  }) : image = ResizeImage.resizeIfNeeded(
            cacheWidth,
            cacheHeight,
            CacheImageProvider.sign(imageLink,
                cacheKey: cacheKey, scale: scale));

  @override
  State<CacheImage> createState() => _CacheImageState();
}

class _CacheImageState extends State<CacheImage> with WidgetsBindingObserver {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  bool _isListeningToStream = false;
  late bool _invertColors;
  int? _frameNumber;
  bool _wasSynchronouslyLoaded = false;
  late DisposableBuildContext<State<CacheImage>> _scrollAwareContext;
  Object? _lastException;
  ImageStreamCompleterHandle? _completerHandle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollAwareContext = DisposableBuildContext<State<CacheImage>>(this);
  }

  @override
  void dispose() {
    assert(_imageStream != null);
    WidgetsBinding.instance.removeObserver(this);
    _stopListeningToStream();
    _completerHandle?.dispose();
    _scrollAwareContext.dispose();
    _replaceImage(info: null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _updateInvertColors();
    _resolveImage();

    if (TickerMode.of(context)) {
      _listenToStream();
    } else {
      _stopListeningToStream(keepStreamAlive: true);
    }

    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(CacheImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _resolveImage();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    setState(() {
      _updateInvertColors();
    });
  }

  @override
  void reassemble() {
    _resolveImage();
    super.reassemble();
  }

  void _updateInvertColors() {
    _invertColors = MediaQuery.maybeInvertColorsOf(context) ??
        SemanticsBinding.instance.accessibilityFeatures.invertColors;
  }

  void _resolveImage() {
    final ScrollAwareImageProvider provider = ScrollAwareImageProvider<Object>(
      context: _scrollAwareContext,
      imageProvider: widget.image,
    );
    final ImageStream newStream =
        provider.resolve(createLocalImageConfiguration(
      context,
      size: widget.width != null && widget.height != null
          ? Size(widget.width!, widget.height!)
          : null,
    ));
    _updateSourceStream(newStream);
  }

  ImageStreamListener? _imageStreamListener;
  ImageStreamListener _getListener({bool recreateListener = false}) {
    if (_imageStreamListener == null || recreateListener) {
      _lastException = null;
      _imageStreamListener = ImageStreamListener(
        _handleImageFrame,
        onError: kDebugMode
            ? (Object error, StackTrace? stackTrace) {
                _lastException = error;
                setState(() {});
              }
            : null,
      );
    }
    return _imageStreamListener!;
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _replaceImage(info: imageInfo);
      _lastException = null;
      _frameNumber = _frameNumber == null ? 0 : _frameNumber! + 1;
      _wasSynchronouslyLoaded = _wasSynchronouslyLoaded | synchronousCall;
    });
  }

  void _replaceImage({required ImageInfo? info}) {
    final ImageInfo? oldImageInfo = _imageInfo;
    SchedulerBinding.instance.addPostFrameCallback(
        (_) => oldImageInfo?.dispose(),
        debugLabel: 'Image.disposeOldInfo');
    _imageInfo = info;
  }

  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key == newStream.key) {
      return;
    }

    if (_isListeningToStream) {
      _imageStream!.removeListener(_getListener());
    }

    setState(() {
      _frameNumber = null;
      _wasSynchronouslyLoaded = false;
    });

    _imageStream = newStream;
    if (_isListeningToStream) {
      _imageStream!.addListener(_getListener());
    }
  }

  void _listenToStream() {
    if (_isListeningToStream) {
      return;
    }

    _imageStream!.addListener(_getListener());
    _completerHandle?.dispose();
    _completerHandle = null;

    _isListeningToStream = true;
  }

  void _stopListeningToStream({bool keepStreamAlive = false}) {
    if (!_isListeningToStream) {
      return;
    }

    if (keepStreamAlive &&
        _completerHandle == null &&
        _imageStream?.completer != null) {
      _completerHandle = _imageStream!.completer!.keepAlive();
    }

    _imageStream!.removeListener(_getListener());
    _isListeningToStream = false;
  }

  Widget _debugBuildErrorWidget(BuildContext context, Object error) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(children: [
        Text('$error', textAlign: TextAlign.center),
      ]),
    );
  }

  Widget cacheFrameBuilder(Widget child) {
    Widget placeholder = Container(
      height: widget.height,
      width: widget.width,
      color: const Color(0xFFF3F3F3),
    );
    if (_frameNumber == null) return placeholder;

    if (_wasSynchronouslyLoaded) return child;
    return CacheImageStack(child, placeholder);
  }

  @override
  Widget build(BuildContext context) {
    if (_lastException != null) {
      if (kDebugMode) {
        return _debugBuildErrorWidget(context, _lastException!);
      }
    }

    Widget result = RawImage(
      image: _imageInfo?.image,
      debugImageLabel: _imageInfo?.debugLabel,
      width: widget.width,
      height: widget.height,
      scale: _imageInfo?.scale ?? 1.0,
      color: widget.color,
      opacity: widget.opacity,
      colorBlendMode: widget.colorBlendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      matchTextDirection: widget.matchTextDirection,
      invertColors: _invertColors,
      isAntiAlias: widget.isAntiAlias,
      filterQuality: widget.filterQuality,
    );

    return cacheFrameBuilder(result);
  }
}

class CacheImageStack extends StatelessWidget {
  const CacheImageStack(this.revealing, this.disappearing, {super.key});

  final Widget revealing;
  final Widget disappearing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [
        CacheFadeWidget(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
          child: revealing,
        ),
        CacheFadeWidget(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          direction: AnimationDirection.reverse,
          child: disappearing,
        )
      ],
    );
  }
}
