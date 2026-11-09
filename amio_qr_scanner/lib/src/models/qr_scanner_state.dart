import 'qr_scanner_config.dart';

/// Trạng thái vòng đời của bộ quét QR.
enum QrScannerStatus {
  initial,
  initializing,
  running,
  paused,
  stopped,
  error,
}

/// Trạng thái hiện tại của `QrScannerController`.
class QrScannerState {
  final QrScannerStatus status;
  final bool hasPermission;
  final QrPermissionStatus permissionStatus;
  final bool isFlashOn;
  final QrCameraFacing cameraFacing;
  final bool isAttached;
  final String? error;

  const QrScannerState({
    this.status = QrScannerStatus.initial,
    this.hasPermission = false,
    this.permissionStatus = QrPermissionStatus.notDetermined,
    this.isFlashOn = false,
    this.cameraFacing = QrCameraFacing.back,
    this.isAttached = false,
    this.error,
  });

  QrScannerState copyWith({
    QrScannerStatus? status,
    bool? hasPermission,
    QrPermissionStatus? permissionStatus,
    bool? isFlashOn,
    QrCameraFacing? cameraFacing,
    bool? isAttached,
    String? error,
    bool clearError = false,
  }) {
    return QrScannerState(
      status: status ?? this.status,
      hasPermission: hasPermission ?? this.hasPermission,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      isAttached: isAttached ?? this.isAttached,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
