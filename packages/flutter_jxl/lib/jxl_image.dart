import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_jxl/ffi.dart';
import 'dart:ui' as ui;

import 'package:jxl/jxl.dart';

final api = createLib();

/// Used to support both Flutter 2.x.x and 3.x.x
///
/// Private since this is the only file that produces
/// binding warnings in the 3.x.x version of flutter.
T? _ambiguate<T>(T? value) => value;

const double _kLowDprLimit = 2.0;

class JxlImage extends StatefulWidget {
  final double? width;
  final double? height;
  final Color? color;
  final Animation<double>? opacity;
  final FilterQuality filterQuality;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool isAntiAlias;
  final ImageProvider image;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool gaplessPlayback;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final CropInfo? cropInfo;

  @override
  State<JxlImage> createState() => JxlImageState();

  const JxlImage({
    super.key,
    required this.image,
    double scale = 1.0,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.loadingBuilder,
    this.cropInfo,
  });

  JxlImage.file(
    File file, {
    super.key,
    double scale = 1.0,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    int? overrideDurationMs = -1,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.cropInfo,
  })  : image = FileJxlImage(
          file,
          scale: scale,
          overrideDurationMs: overrideDurationMs,
          cropInfo: cropInfo,
        ),
        loadingBuilder = null;

  JxlImage.asset(
    String name, {
    super.key,
    double scale = 1.0,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    int? overrideDurationMs = -1,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.frameBuilder,
    AssetBundle? bundle,
    this.cropInfo,
  })  : image = AssetJxlCodecImage(
          name,
          scale: scale,
          overrideDurationMs: overrideDurationMs,
          bundle: bundle,
          cropInfo: cropInfo,
        ),
        loadingBuilder = null;

  JxlImage.network(
    String url, {
    super.key,
    double scale = 1.0,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    int? overrideDurationMs = -1,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.loadingBuilder,
    Map<String, String>? headers,
    this.cropInfo,
  }) : image = NetworkJxlImage(
          url,
          scale: scale,
          overrideDurationMs: overrideDurationMs,
          headers: headers,
          cropInfo: cropInfo,
        );

  JxlImage.memory(
    Uint8List bytes, {
    super.key,
    double scale = 1.0,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
    int? overrideDurationMs = -1,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.frameBuilder,
    this.cropInfo,
  })  : image = MemoryJxlImage(
          bytes,
          scale: scale,
          overrideDurationMs: overrideDurationMs,
          cropInfo: cropInfo,
        ),
        loadingBuilder = null;
}

class JxlImageState extends State<JxlImage> with WidgetsBindingObserver {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  bool _isListeningToStream = false;
  late bool _invertColors;
  late DisposableBuildContext<State<JxlImage>> _scrollAwareContext;
  ImageStreamCompleterHandle? _completerHandle;
  int? _frameNumber;
  Object? _lastException;
  StackTrace? _lastStack;
  bool _wasSynchronouslyLoaded = false;
  ImageChunkEvent? _loadingProgress;

  @override
  void initState() {
    super.initState();
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);
    _scrollAwareContext = DisposableBuildContext<State<JxlImage>>(this);
  }

  @override
  void dispose() {
    assert(_imageStream != null);
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
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
  void didUpdateWidget(JxlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isListeningToStream &&
        (widget.loadingBuilder == null) != (oldWidget.loadingBuilder == null)) {
      final ImageStreamListener oldListener = _getListener();
      _imageStream!.addListener(_getListener(recreateListener: true));
      _imageStream!.removeListener(oldListener);
    }
    if (widget.image != oldWidget.image ||
        widget.cropInfo != oldWidget.cropInfo) {
      widget.image.evict();
      api.disposeDecoder(key: oldWidget.image.hashCode.toString());
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

  ImageStreamListener? _imageStreamListener;
  ImageStreamListener _getListener({bool recreateListener = false}) {
    if (_imageStreamListener == null || recreateListener) {
      _lastException = null;
      _lastStack = null;
      _imageStreamListener = ImageStreamListener(
        _handleImageFrame,
        onChunk: widget.loadingBuilder == null ? null : _handleImageChunk,
        onError: widget.errorBuilder != null || kDebugMode
            ? (Object error, StackTrace? stackTrace) {
                setState(() {
                  _lastException = error;
                  _lastStack = stackTrace;
                });
                assert(() {
                  if (widget.errorBuilder == null) {
                    // ignore: only_throw_errors, since we're just proxying the error.
                    throw error; // Ensures the error message is printed to the console.
                  }
                  return true;
                }());
              }
            : null,
      );
    }
    return _imageStreamListener!;
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _lastException = null;
      _lastStack = null;
      _replaceImage(info: imageInfo);
      _frameNumber = _frameNumber == null ? 0 : _frameNumber! + 1;
      _wasSynchronouslyLoaded = _wasSynchronouslyLoaded | synchronousCall;
      _loadingProgress = null;
    });
  }

  void _handleImageChunk(ImageChunkEvent event) {
    assert(widget.loadingBuilder != null);
    setState(() {
      _loadingProgress = event;
      _lastException = null;
      _lastStack = null;
    });
  }

  void _listenToStream() {
    if (_isListeningToStream) return;

    _imageStream!.addListener(_getListener());
    _completerHandle?.dispose();
    _completerHandle = null;

    _isListeningToStream = true;
  }

  void _stopListeningToStream({bool keepStreamAlive = false}) {
    if (!_isListeningToStream) return;

    if (keepStreamAlive &&
        _completerHandle == null &&
        _imageStream?.completer != null) {
      _completerHandle = _imageStream!.completer!.keepAlive();
    }

    _imageStream!.removeListener(_getListener());
    _isListeningToStream = false;

    if (_imageStream?.completer != null &&
        !(_imageStream!.completer! as JxlImageStreamCompleter)
            .getHasListeners() &&
        !PaintingBinding.instance.imageCache.containsKey(widget.image)) {
      api.disposeDecoder(key: widget.image.hashCode.toString());
    }
  }

  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key == newStream.key) return;

    if (_isListeningToStream) _imageStream!.removeListener(_getListener());

    if (!widget.gaplessPlayback) {
      setState(() {
        _replaceImage(info: null);
      });
    }

    setState(() {
      _frameNumber = null;
      _wasSynchronouslyLoaded = false;
      _loadingProgress = null;
    });

    _imageStream = newStream;
    if (_isListeningToStream) _imageStream!.addListener(_getListener());
  }

  void _updateInvertColors() {
    _invertColors = MediaQuery.maybeOf(context)?.invertColors ??
        _ambiguate(SemanticsBinding.instance)
            ?.accessibilityFeatures
            .invertColors ??
        false;
  }

  void _replaceImage({required ImageInfo? info}) {
    _imageInfo?.dispose();
    _imageInfo = info;
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

  @override
  Widget build(BuildContext context) {
    if (_lastException != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _lastException!, _lastStack);
      }
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

    if (!widget.excludeFromSemantics) {
      result = Semantics(
        container: widget.semanticLabel != null,
        image: true,
        label: widget.semanticLabel ?? '',
        child: result,
      );
    }

    if (widget.frameBuilder != null) {
      result = widget.frameBuilder!(
        context,
        result,
        _frameNumber,
        _wasSynchronouslyLoaded,
      );
    }

    if (widget.loadingBuilder != null) {
      result = widget.loadingBuilder!(context, result, _loadingProgress);
    }

    return result;
  }

  Widget _debugBuildErrorWidget(BuildContext context, Object error) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        const Positioned.fill(
          child: Placeholder(
            color: Color(0xCF8D021F),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: FittedBox(
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                shadows: <Shadow>[
                  Shadow(blurRadius: 1.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FileJxlImage extends ImageProvider<FileJxlImage> {
  const FileJxlImage(
    this.file, {
    this.scale = 1.0,
    this.overrideDurationMs = -1,
    this.cropInfo,
  });

  final File file;
  final double scale;
  final int? overrideDurationMs;
  final CropInfo? cropInfo;

  @override
  Future<FileJxlImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FileJxlImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      FileJxlImage key, ImageDecoderCallback decode) {
    return JxlImageStreamCompleter(
      key: key,
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
      ],
    );
  }

  Future<JxlCodec> _loadAsync(
    FileJxlImage key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      _ambiguate(PaintingBinding.instance)?.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }

    final isJxl = await api.isJxl(jxlBytes: bytes);

    if (!isJxl) {
      throw StateError('$file is not an Jxl file.');
    }

    final codec = MultiFrameJxlCodec(
      key: hashCode,
      jxlBytes: bytes,
      overrideDurationMs: overrideDurationMs,
      cropInfo: cropInfo,
    );
    await codec.ready();

    return codec;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is FileJxlImage &&
        other.file.path == file.path &&
        other.scale == scale &&
        other.cropInfo == cropInfo;
  }

  @override
  int get hashCode => Object.hash(file.path, scale, cropInfo);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'JxlImage')}("${file.path}", scale: $scale, cropInfo: $cropInfo)';
}

class AssetJxlCodecImage extends ImageProvider<AssetJxlCodecImage> {
  const AssetJxlCodecImage(
    this.asset, {
    this.scale = 1.0,
    this.overrideDurationMs = -1,
    this.bundle,
    this.cropInfo,
  });

  final String asset;
  final double scale;
  final int? overrideDurationMs;
  final CropInfo? cropInfo;
  final AssetBundle? bundle;

  static const double _naturalResolution = 1.0;

  @override
  Future<AssetJxlCodecImage> obtainKey(ImageConfiguration configuration) async {
    final chosenBundle = bundle ?? rootBundle;

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(chosenBundle);
      final Iterable<AssetMetadata>? candidateVariants =
          manifest.getAssetVariants(asset);
      final AssetMetadata chosenVariant = _chooseVariant(
        asset,
        configuration,
        candidateVariants,
      );

      return AssetJxlCodecImage(
        chosenVariant.key,
        bundle: chosenBundle,
        scale: chosenVariant.targetDevicePixelRatio ?? _naturalResolution,
      );
    } catch (e) {
      return this;
    }
  }

  @override
  ImageStreamCompleter loadImage(
      AssetJxlCodecImage key, ImageDecoderCallback decode) {
    return JxlImageStreamCompleter(
      key: key,
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.asset,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Asset: $asset'),
      ],
    );
  }

  Future<JxlCodec> _loadAsync(
    AssetJxlCodecImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await (bundle ?? rootBundle).load(key.asset);

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      _ambiguate(PaintingBinding.instance)?.imageCache.evict(key);
      throw StateError('$asset is empty and cannot be loaded as an image.');
    }

    final bytesUint8List = bytes.buffer.asUint8List(0);

    final isJxl = await api.isJxl(jxlBytes: bytesUint8List);

    if (!isJxl) {
      throw StateError('$asset is not an Jxl file.');
    }

    final codec = MultiFrameJxlCodec(
      key: hashCode,
      jxlBytes: bytesUint8List,
      overrideDurationMs: overrideDurationMs,
      cropInfo: cropInfo,
    );
    await codec.ready();

    return codec;
  }

  AssetMetadata _chooseVariant(
    String mainAssetKey,
    ImageConfiguration config,
    Iterable<AssetMetadata>? candidateVariants,
  ) {
    if (candidateVariants == null ||
        candidateVariants.isEmpty ||
        config.devicePixelRatio == null) {
      return AssetMetadata(
          key: mainAssetKey, targetDevicePixelRatio: null, main: true);
    }

    final SplayTreeMap<double, AssetMetadata> candidatesByDevicePixelRatio =
        SplayTreeMap<double, AssetMetadata>();
    for (final AssetMetadata candidate in candidateVariants) {
      candidatesByDevicePixelRatio[
          candidate.targetDevicePixelRatio ?? _naturalResolution] = candidate;
    }

    return _findBestVariant(
        candidatesByDevicePixelRatio, config.devicePixelRatio!);
  }

  AssetMetadata _findBestVariant(
    SplayTreeMap<double, AssetMetadata> candidatesByDpr,
    double value,
  ) {
    if (candidatesByDpr.containsKey(value)) {
      return candidatesByDpr[value]!;
    }
    final double? lower = candidatesByDpr.lastKeyBefore(value);
    final double? upper = candidatesByDpr.firstKeyAfter(value);
    if (lower == null) {
      return candidatesByDpr[upper]!;
    }
    if (upper == null) {
      return candidatesByDpr[lower]!;
    }

    if (value < _kLowDprLimit || value > (lower + upper) / 2) {
      return candidatesByDpr[upper]!;
    } else {
      return candidatesByDpr[lower]!;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is AssetJxlCodecImage &&
        other.asset == asset &&
        other.scale == scale &&
        other.cropInfo == cropInfo;
  }

  @override
  int get hashCode => Object.hash(asset, scale, cropInfo);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'JxlCodecImage')}("$asset", scale: $scale, cropInfo: $cropInfo)';
}

class NetworkJxlImage extends ImageProvider<NetworkJxlImage> {
  const NetworkJxlImage(
    this.url, {
    this.scale = 1.0,
    this.overrideDurationMs = -1,
    this.headers,
    this.cropInfo,
  });

  final String url;
  final double scale;
  final int? overrideDurationMs;
  final CropInfo? cropInfo;
  final Map<String, String>? headers;

  @override
  Future<NetworkJxlImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkJxlImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      NetworkJxlImage key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return JxlImageStreamCompleter(
      key: key,
      codec: _loadAsync(
        key,
        decode,
        chunkEvents,
      ),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Url: $url'),
      ],
      chunkEvents: chunkEvents.stream,
    );
  }

  Future<JxlCodec> _loadAsync(
    NetworkJxlImage key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    assert(key == this);

    final httpClient = HttpClient();
    final httpRequest = await httpClient.getUrl(Uri.parse(url));
    headers?.forEach((String name, String value) {
      httpRequest.headers.add(name, value);
    });
    final httpResponse = await httpRequest.close();
    if (httpResponse.statusCode != HttpStatus.ok) {
      throw StateError(
          '$url cannot be loaded as an image. Http error code ${httpResponse.statusCode}');
    }
    final Uint8List bytes = await consolidateHttpClientResponseBytes(
      httpResponse,
      onBytesReceived: (int cumulative, int? total) {
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: cumulative,
          expectedTotalBytes: total,
        ));
      },
    );

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      _ambiguate(PaintingBinding.instance)?.imageCache.evict(key);
      throw StateError('$url is empty and cannot be loaded as an image.');
    }

    final isJxl = await api.isJxl(jxlBytes: bytes);

    if (!isJxl) {
      throw StateError('$url is not a JXL image.');
    }

    final codec = MultiFrameJxlCodec(
      key: hashCode,
      jxlBytes: bytes,
      overrideDurationMs: overrideDurationMs,
      cropInfo: cropInfo,
    );
    await codec.ready();

    return codec;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NetworkJxlImage &&
        other.url == url &&
        other.scale == scale &&
        other.cropInfo == cropInfo;
  }

  @override
  int get hashCode => Object.hash(url, scale, cropInfo);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'JxlImage')}("$url", scale: $scale, cropInfo: $cropInfo)';
}

class MemoryJxlImage extends ImageProvider<MemoryJxlImage> {
  const MemoryJxlImage(
    this.bytes, {
    this.scale = 1.0,
    this.overrideDurationMs = -1,
    this.cropInfo,
  });

  final Uint8List bytes;
  final double scale;
  final int? overrideDurationMs;
  final CropInfo? cropInfo;

  @override
  Future<MemoryJxlImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MemoryJxlImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      MemoryJxlImage key, ImageDecoderCallback decode) {
    return JxlImageStreamCompleter(
      key: key,
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: 'MemoryJxlImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<JxlCodec> _loadAsync(
      MemoryJxlImage key, ImageDecoderCallback decode) async {
    assert(key == this);

    final bytesUint8List = bytes.buffer.asUint8List(0);

    final isJxl = await api.isJxl(jxlBytes: bytesUint8List);

    if (!isJxl) {
      throw StateError('The bytes are not an Jxl file.');
    }

    final codec = MultiFrameJxlCodec(
      key: hashCode,
      jxlBytes: bytesUint8List,
      overrideDurationMs: overrideDurationMs,
      cropInfo: cropInfo,
    );
    await codec.ready();

    return codec;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MemoryJxlImage &&
        other.bytes == bytes &&
        other.scale == scale &&
        other.cropInfo == cropInfo;
  }

  @override
  int get hashCode => Object.hash(bytes.hashCode, scale, cropInfo);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'MemoryJxlImage')}(${describeIdentity(bytes)}, scale: $scale, cropInfo: $cropInfo)';
}

class JxlImageStreamCompleter extends ImageStreamCompleter {
  JxlImageStreamCompleter({
    required ImageProvider key,
    required Future<JxlCodec> codec,
    required double scale,
    String? debugLabel,
    Stream<ImageChunkEvent>? chunkEvents,
    InformationCollector? informationCollector,
    this.cropInfo,
  })  : _informationCollector = informationCollector,
        _scale = scale,
        _key = key {
    this.debugLabel = debugLabel;
    codec.then<void>(_handleCodecReady,
        onError: (Object error, StackTrace stack) {
      reportError(
        context: ErrorDescription('resolving an image codec'),
        exception: error,
        stack: stack,
        informationCollector: informationCollector,
        silent: true,
      );
    });
    if (chunkEvents != null) {
      _chunkSubscription = chunkEvents.listen(
        reportImageChunkEvent,
        onError: (Object error, StackTrace stack) {
          reportError(
            context: ErrorDescription('loading an image'),
            exception: error,
            stack: stack,
            informationCollector: informationCollector,
            silent: true,
          );
        },
      );
    }
  }

  StreamSubscription<ImageChunkEvent>? _chunkSubscription;
  JxlCodec? _codec;
  final double _scale;
  final InformationCollector? _informationCollector;
  JxlFrameInfo? _nextFrame;
  ImageInfo? _currentFrame;
  late Duration _shownTimestamp;
  Duration? _frameDuration;
  int _duration = 0;
  Timer? _timer;
  final ImageProvider _key;
  CropInfo? cropInfo;

  bool _frameCallbackScheduled = false;

  void _handleCodecReady(JxlCodec codec) {
    _codec = codec;
    assert(_codec != null);

    if (hasListeners) {
      _decodeNextFrameAndSchedule();
    }
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (!hasListeners) return;
    assert(_nextFrame != null);
    if (_isFirstFrame() || _hasFrameDurationPassed(timestamp)) {
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _shownTimestamp = timestamp;
      _frameDuration = _nextFrame!.duration;
      _nextFrame!.image.dispose();
      _nextFrame = null;
      if (_codec!.durationMs == -1 || _codec!.durationMs > _duration) {
        _decodeNextFrameAndSchedule();
      }
      return;
    }
    final Duration delay = _frameDuration! - (timestamp - _shownTimestamp);
    _timer = Timer(delay * timeDilation, () {
      _scheduleAppFrame();
    });
  }

  bool _isFirstFrame() {
    return _frameDuration == null;
  }

  bool _hasFrameDurationPassed(Duration timestamp) {
    return timestamp - _shownTimestamp >= _frameDuration!;
  }

  Future<void> _decodeNextFrameAndSchedule() async {
    _nextFrame?.image.dispose();
    _nextFrame = null;
    try {
      _nextFrame = await _codec!.getNextFrame();
    } catch (exception, stack) {
      reportError(
        context: ErrorDescription('resolving an image frame'),
        exception: exception,
        stack: stack,
        informationCollector: _informationCollector,
        silent: true,
      );
      return;
    }
    if (_codec!.frameCount == 1) {
      if (!hasListeners) {
        return;
      }
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _nextFrame!.image.dispose();
      _nextFrame = null;
      return;
    }
    _scheduleAppFrame();
  }

  void _scheduleAppFrame() {
    if (_frameCallbackScheduled) {
      return;
    }
    _frameCallbackScheduled = true;
    _ambiguate(SchedulerBinding.instance)!
        .scheduleFrameCallback(_handleAppFrame);
  }

  void _emitFrame(ImageInfo imageInfo) {
    setImage(imageInfo);
    _duration += _nextFrame?.duration.inMilliseconds ?? 0;
  }

  @override
  void addListener(ImageStreamListener listener) {
    if (!hasListeners &&
        _codec != null &&
        (_currentFrame == null || _codec!.frameCount > 1)) {
      _decodeNextFrameAndSchedule();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool getHasListeners() => hasListeners;

  @override
  void setImage(ImageInfo image) {
    _currentFrame = image;
    super.setImage(image);
  }

  void dispose() {
    _chunkSubscription?.onData(null);
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
  }

  @override
  ImageStreamCompleterHandle keepAlive() {
    final handle = super.keepAlive();
    return JxlImageStreamCompleterHandle(handle, this);
  }
}

class JxlImageStreamCompleterHandle implements ImageStreamCompleterHandle {
  final ImageStreamCompleterHandle _handle;
  final JxlImageStreamCompleter _completer;

  JxlImageStreamCompleterHandle(this._handle, this._completer);

  @override
  void dispose() {
    _handle.dispose();
    if (!_completer.getHasListeners() &&
        !PaintingBinding.instance.imageCache.containsKey(_completer._key)) {
      _completer._codec?.dispose();
    }
  }
}

abstract class JxlCodec {
  int get frameCount;
  int get durationMs;

  Future<void> ready();
  Future<JxlFrameInfo> getNextFrame();
  void dispose();
}

class JxlFrameInfo {
  final Duration duration;
  final ui.Image image;

  JxlFrameInfo({required this.duration, required this.image});
}

class MultiFrameJxlCodec implements JxlCodec {
  final String _key;
  final CropInfo? _cropInfo;
  late Completer<void> _ready;

  int _frameCount = 1;
  @override
  int get frameCount => _frameCount;

  int _durationMs = -1;
  @override
  int get durationMs => _durationMs;

  MultiFrameJxlCodec({
    required int key,
    required Uint8List jxlBytes,
    int? overrideDurationMs = -1,
    CropInfo? cropInfo,
  })  : _key = key.toString(),
        _cropInfo = cropInfo {
    _ready = Completer();
    try {
      api.initDecoder(key: _key, jxlBytes: jxlBytes).then((info) {
        _frameCount = info.imageCount;
        _durationMs = overrideDurationMs ?? info.duration.round();
        _ready.complete();
      });
    } catch (e) {
      _ready.complete();
    }
  }

  @override
  ready() async {
    if (_ready.isCompleted) {
      return;
    }
    await _ready.future;
  }

  @override
  Future<JxlFrameInfo> getNextFrame() async {
    final Completer<JxlFrameInfo> completer = Completer<JxlFrameInfo>.sync();
    final String? error =
        _getNextFrame((ui.Image? image, int durationMilliseconds) {
      if (image == null) {
        completer.completeError(Exception(
            'Codec failed to produce an image, possibly due to invalid image data.'));
      } else {
        completer.complete(JxlFrameInfo(
          image: image,
          duration: Duration(milliseconds: durationMilliseconds),
        ));
      }
    });
    if (error != null) {
      throw Exception(error);
    }
    return completer.future;
  }

  String? _getNextFrame(void Function(ui.Image?, int) callback) {
    try {
      api.getNextFrame(key: _key, cropInfo: _cropInfo).then((frame) {
        final (data, width, height) = (frame.data, frame.width, frame.height);

        var targetRgbaLength = width * height * 4;

        final hasAlpha = data.length == targetRgbaLength;

        late final Float32List? modifiedData;

        if (!hasAlpha) {
          modifiedData = Float32List(targetRgbaLength);

          for (var i = 0; i < data.length; i += 3) {
            final index = i * 4 ~/ 3;
            modifiedData[index] = data[i];
            modifiedData[index + 1] = data[i + 1];
            modifiedData[index + 2] = data[i + 2];
            modifiedData[index + 3] = 1.0;
          }
        } else {
          modifiedData = null;
        }

        ui.decodeImageFromPixels(
          (modifiedData ?? data).buffer.asUint8List(),
          frame.width,
          frame.height,
          ui.PixelFormat.rgbaFloat32,
          (image) {
            callback(image, frame.duration.round());
          },
        );
      });
      return null;
    } catch (e) {
      callback(null, 0);
      return e.toString();
    }
  }

  @override
  void dispose() {
    api.disposeDecoder(key: _key);
  }
}
