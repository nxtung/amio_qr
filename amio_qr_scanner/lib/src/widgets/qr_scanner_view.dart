import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/qr_scanner_controller.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scanner_state.dart';
import '../platform/qr_scanner_platform.dart';
import 'qr_scanner_overlay.dart';

/// Widget hiển thị Camera preview từ Native kết hợp với lớp phủ khung ngắm QR của Flutter.
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.controller,
    this.onDetect,
    this.onError,
    this.overlayColor = Colors.black54,
    this.scanLineColor = const Color(0xFFF26F25),
    this.overlayBuilder,
  });

  final QrScannerController controller;
  final ValueChanged<QRScanResult>? onDetect;
  final ValueChanged<String>? onError;
  final Color overlayColor;
  final Color scanLineColor;
  final WidgetBuilder? overlayBuilder;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with WidgetsBindingObserver {
  StreamSubscription<QRScanResult>? _resultSubscription;
  String? _lastError;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant QrScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller);
    }
  }

  void _bindController(QrScannerController controller) {
    _resultSubscription = controller.results.listen((result) {
      if (mounted) {
        widget.onDetect?.call(result);
      }
    });
    controller.addListener(_onControllerChanged);
  }

  void _unbindController(QrScannerController controller) {
    _resultSubscription?.cancel();
    _resultSubscription = null;
    controller.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final state = widget.controller.state;
    if (state.status == QrScannerStatus.error &&
        state.error != null &&
        state.error != _lastError) {
      _lastError = state.error;
      widget.onError?.call(state.error!);
    } else if (state.status != QrScannerStatus.error) {
      _lastError = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.controller.handleAppLifecyclePause();
      case AppLifecycleState.resumed:
        widget.controller.handleAppLifecycleResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unbindController(widget.controller);
    super.dispose();
  }

  void _scheduleLayoutSync(Size size) {
    if (size == _lastSize || size.width <= 0 || size.height <= 0) return;
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.isDisposed) {
        widget.controller.updateScanLayout(
          viewWidth: size.width,
          viewHeight: size.height,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const viewType = QrScannerPlatform.viewType;
    final config = widget.controller.config;
    final creationParams = <String, dynamic>{
      'cameraFacing': config.cameraFacing.name,
      'enableFlash': config.enableFlash,
      'detectionTimeout': config.detectionTimeout.inMilliseconds,
      'duplicateTimeout': config.duplicateTimeout.inMilliseconds,
      'scanWindowSize': config.scanWindowSize,
      'restrictToScanWindow': config.restrictToScanWindow,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleLayoutSync(constraints.biggest);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (defaultTargetPlatform == TargetPlatform.android)
              AndroidView(
                viewType: viewType,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: widget.controller.attach,
              )
            else if (defaultTargetPlatform == TargetPlatform.iOS)
              UiKitView(
                viewType: viewType,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: widget.controller.attach,
              )
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Text(
                    'Platform not supported',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            if (widget.overlayBuilder != null)
              widget.overlayBuilder!(context)
            else if (config.showOverlay)
              QrScannerOverlay(
                color: widget.overlayColor,
                scanLineColor: widget.scanLineColor,
                animated: config.showAnimation,
                windowSize: config.scanWindowSize,
              ),
          ],
        );
      },
    );
  }
}
