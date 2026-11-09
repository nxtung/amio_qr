import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/qr_scan_result.dart';
import '../models/qr_scanner_config.dart';
import '../models/qr_scanner_state.dart';
import '../platform/qr_scanner_platform.dart';

/// Bộ điều khiển trung tâm quản lý trạng thái Camera, giao tiếp Native và dòng sự kiện kết quả QR.
class QrScannerController extends ChangeNotifier {
  QrScannerController({
    this.config = const QrScannerConfig(),
  }) : _state = QrScannerState(
          cameraFacing: config.cameraFacing,
          isFlashOn: config.enableFlash,
        );

  final QrScannerConfig config;

  QrScannerState _state;

  QrScannerState get state => _state;

  int? _viewId;
  int? get viewId => _viewId;

  MethodChannel? _methodChannel;
  EventChannel? _eventChannel;

  StreamSubscription<dynamic>? _subscription;

  final StreamController<QRScanResult> _resultController =
      StreamController<QRScanResult>.broadcast();

  /// Stream phát kết quả mỗi khi quét được mã QR hợp lệ.
  Stream<QRScanResult> get results => _resultController.stream;

  String? _lastValue;
  DateTime? _lastDetectedAt;

  double _viewWidth = 0;
  double _viewHeight = 0;

  bool _pendingStart = false;
  bool _wasRunningBeforeLifecyclePause = false;
  bool _isStarting = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _update(QrScannerState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  /// Được gọi bởi `QrScannerView` khi PlatformView khởi tạo xong ở tầng Native.
  void attach(int viewId) {
    if (_disposed) return;

    _viewId = viewId;
    _subscription?.cancel();

    _methodChannel = QrScannerPlatform.createViewMethodChannel(viewId);
    _eventChannel = QrScannerPlatform.createViewEventChannel(viewId);

    _subscription = _eventChannel!.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        _update(
          _state.copyWith(
            status: QrScannerStatus.error,
            error: error.toString(),
          ),
        );
      },
    );

    _update(_state.copyWith(isAttached: true));

    if (_pendingStart || config.autoStart) {
      _pendingStart = false;
      unawaited(start());
    }
  }

  /// Cập nhật kích thước khung hiển thị thực tế của `QrScannerView` để Native tính toán vùng ROI chính xác.
  Future<void> updateScanLayout({
    required double viewWidth,
    required double viewHeight,
  }) async {
    if (_disposed) return;
    if (viewWidth <= 0 || viewHeight <= 0) return;
    if ((_viewWidth - viewWidth).abs() < 0.5 &&
        (_viewHeight - viewHeight).abs() < 0.5) {
      return;
    }

    _viewWidth = viewWidth;
    _viewHeight = viewHeight;

    if (_state.isAttached) {
      await _invoke<void>('updateScanWindow', <String, dynamic>{
        'scanWindowSize': config.scanWindowSize,
        'restrictToScanWindow': config.restrictToScanWindow,
        'viewWidth': _viewWidth,
        'viewHeight': _viewHeight,
      });
    }
  }

  void _handleEvent(dynamic event) {
    if (_disposed || event is! Map) return;

    final type = event['type'];

    if (type == 'result') {
      // Không phát kết quả camera nếu scanner đã tạm dừng hoặc dừng hẳn.
      if (_state.status != QrScannerStatus.running) return;

      final result = QRScanResult.fromMap(event);
      if (result.value.isEmpty) return;

      final now = DateTime.now();

      if (_lastValue == result.value &&
          _lastDetectedAt != null &&
          now.difference(_lastDetectedAt!) < config.duplicateTimeout) {
        return;
      }

      _lastValue = result.value;
      _lastDetectedAt = now;

      if (!_resultController.isClosed) {
        _resultController.add(result);
      }
    } else if (type == 'error') {
      _update(
        _state.copyWith(
          status: QrScannerStatus.error,
          error: event['message']?.toString(),
        ),
      );
    } else if (type == 'state') {
      final flash = event['isFlashOn'] as bool?;
      if (flash != null) {
        _update(_state.copyWith(isFlashOn: flash));
      }
    }
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final channel = _methodChannel;
    if (channel == null || _disposed) return null;

    return channel.invokeMethod<T>(method, arguments);
  }

  /// Kiểm tra trạng thái quyền truy cập Camera hiện tại mà không hiện popup.
  Future<QrPermissionStatus> checkPermission() async {
    try {
      final status = await QrScannerPlatform.instance.checkPermission();
      _update(
        _state.copyWith(
          hasPermission: status.isGranted,
          permissionStatus: status,
        ),
      );
      return status;
    } catch (_) {
      return _state.permissionStatus;
    }
  }

  /// Yêu cầu quyền Camera và trả về `QrPermissionStatus` chi tiết (hỗ trợ phát hiện `permanentlyDenied`).
  Future<QrPermissionStatus> requestPermissionStatus() async {
    try {
      final status = await QrScannerPlatform.instance.requestPermission();
      _update(
        _state.copyWith(
          hasPermission: status.isGranted,
          permissionStatus: status,
        ),
      );
      return status;
    } catch (_) {
      final granted = await _invoke<bool>('requestPermission') ?? false;
      final status =
          granted ? QrPermissionStatus.granted : QrPermissionStatus.denied;
      _update(
        _state.copyWith(
          hasPermission: granted,
          permissionStatus: status,
        ),
      );
      return status;
    }
  }

  /// Yêu cầu quyền Camera (trả về `true` nếu được cấp quyền).
  Future<bool> requestPermission() async {
    final status = await requestPermissionStatus();
    return status.isGranted;
  }

  /// Mở trang Cài đặt ứng dụng của hệ thống khi quyền Camera bị từ chối vĩnh viễn.
  Future<bool> openAppSettings() {
    return QrScannerPlatform.instance.openAppSettings();
  }

  /// Quét mã QR từ một đường dẫn file ảnh tĩnh.
  Future<QRScanResult?> scanImagePath(
    String path, {
    bool emitToStream = true,
  }) async {
    if (_disposed) return null;
    try {
      final result = await QrScannerPlatform.instance.scanImagePath(path);
      if (result != null && emitToStream && !_resultController.isClosed) {
        _resultController.add(result);
      }
      return result;
    } on PlatformException catch (e) {
      _update(
        _state.copyWith(
          error: e.message ?? 'Không thể đọc ảnh QR',
        ),
      );
      return null;
    }
  }

  /// Mở thư viện ảnh hệ thống để chọn ảnh và quét mã QR.
  Future<QRScanResult?> pickAndScanImage({
    bool emitToStream = true,
  }) async {
    if (_disposed) return null;
    final wasRunning = _state.status == QrScannerStatus.running;
    if (wasRunning) {
      await pause();
    }

    try {
      final result = await QrScannerPlatform.instance.pickAndScanImage();
      if (result != null && emitToStream && !_resultController.isClosed) {
        _resultController.add(result);
      } else if (wasRunning && !_disposed) {
        await resume();
      }
      return result;
    } on PlatformException catch (e) {
      if (wasRunning && !_disposed) {
        await resume();
      }
      _update(
        _state.copyWith(
          error: e.message ?? 'Không thể quét ảnh từ thư viện',
        ),
      );
      return null;
    }
  }

  /// Khởi động camera và bắt đầu phân tích mã QR.
  /// Nếu PlatformView chưa được attach, lệnh sẽ được xếp hàng và tự động chạy ngay khi attach xong.
  Future<void> start() async {
    if (_disposed || _isStarting) return;

    if (!_state.isAttached || _methodChannel == null) {
      _pendingStart = true;
      return;
    }

    _isStarting = true;

    try {
      _update(
        _state.copyWith(
          status: QrScannerStatus.initializing,
          clearError: true,
        ),
      );

      final permissionStatus = await requestPermissionStatus();

      if (!permissionStatus.isGranted) {
        _update(
          _state.copyWith(
            status: QrScannerStatus.error,
            hasPermission: false,
            permissionStatus: permissionStatus,
            error: permissionStatus.isPermanentlyDenied
                ? 'Quyền truy cập Camera đã bị từ chối vĩnh viễn. Vui lòng bật trong Cài đặt.'
                : 'Chưa được cấp quyền truy cập Camera.',
          ),
        );
        return;
      }

      await _invoke<void>('start', <String, dynamic>{
        'cameraFacing': _state.cameraFacing.name,
        'enableFlash': config.enableFlash,
        'detectionTimeout': config.detectionTimeout.inMilliseconds,
        'duplicateTimeout': config.duplicateTimeout.inMilliseconds,
        'scanWindowSize': config.scanWindowSize,
        'restrictToScanWindow': config.restrictToScanWindow,
        'viewWidth': _viewWidth,
        'viewHeight': _viewHeight,
      });

      _update(
        _state.copyWith(
          status: QrScannerStatus.running,
          hasPermission: true,
          permissionStatus: QrPermissionStatus.granted,
          clearError: true,
        ),
      );
    } on PlatformException catch (e) {
      _update(
        _state.copyWith(
          status: QrScannerStatus.error,
          error: e.message ?? 'Khởi tạo Camera thất bại',
        ),
      );
    } finally {
      _isStarting = false;
    }
  }

  /// Dừng hẳn camera.
  Future<void> stop() async {
    if (_disposed) return;
    _pendingStart = false;
    _wasRunningBeforeLifecyclePause = false;

    if (_state.isAttached) {
      await _invoke<void>('stop');
    }

    _update(
      _state.copyWith(
        status: QrScannerStatus.stopped,
        isFlashOn: false,
      ),
    );
  }

  /// Tạm dừng nhận diện và giải phóng phiên camera tạm thời.
  Future<void> pause() async {
    if (_disposed) return;
    _pendingStart = false;

    if (_state.isAttached) {
      await _invoke<void>('pause');
    }

    _update(
      _state.copyWith(
        status: QrScannerStatus.paused,
        isFlashOn: false,
      ),
    );
  }

  /// Tiếp tục quét sau khi `pause()`.
  Future<void> resume() async {
    if (_disposed) return;
    await start();
  }

  /// Được gọi bởi `QrScannerView` khi ứng dụng chuyển xuống nền.
  Future<void> handleAppLifecyclePause() async {
    if (_disposed) return;
    if (_state.status == QrScannerStatus.running ||
        _state.status == QrScannerStatus.initializing) {
      _wasRunningBeforeLifecyclePause = true;
      await pause();
    }
  }

  /// Được gọi bởi `QrScannerView` khi ứng dụng quay trở lại foreground.
  Future<void> handleAppLifecycleResume() async {
    if (_disposed || !_state.isAttached) return;

    if (_wasRunningBeforeLifecyclePause) {
      _wasRunningBeforeLifecyclePause = false;
      await resume();
      return;
    }

    // Nếu trước đó đang ở trạng thái lỗi do thiếu quyền và người dùng vừa từ Cài đặt quay lại
    if (_state.status == QrScannerStatus.error && !_state.hasPermission) {
      final status = await checkPermission();
      if (status.isGranted) {
        await start();
      }
    }
  }

  /// Bật / tắt đèn Flash (Torch).
  Future<void> toggleFlash() async {
    if (_disposed || !_state.isAttached) return;
    final enabled = await _invoke<bool>('toggleFlash');

    _update(
      _state.copyWith(
        isFlashOn: enabled ?? false,
      ),
    );
  }

  /// Chuyển đổi giữa camera trước và camera sau.
  Future<void> switchCamera() async {
    if (_disposed || !_state.isAttached) return;
    final facing = await _invoke<String>('switchCamera');

    if (facing == null) return;

    _update(
      _state.copyWith(
        cameraFacing:
            facing == 'front' ? QrCameraFacing.front : QrCameraFacing.back,
        isFlashOn: false,
      ),
    );
  }

  /// Xóa bộ nhớ đệm chống trùng mã QR ở cả tầng Dart và Native.
  Future<void> resetDetection() async {
    _lastValue = null;
    _lastDetectedAt = null;
    if (!_disposed && _state.isAttached) {
      await _invoke<void>('resetDetection');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;

    _subscription?.cancel();
    _subscription = null;

    if (_state.isAttached) {
      _methodChannel?.invokeMethod<void>('stop');
    }

    _disposed = true;

    _resultController.close();

    super.dispose();
  }
}
