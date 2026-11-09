/// Hướng camera sử dụng để quét mã QR.
enum QrCameraFacing {
  back,
  front,
}

/// Trạng thái quyền truy cập Camera chi tiết.
enum QrPermissionStatus {
  /// Chưa từng hỏi quyền.
  notDetermined,

  /// Đã được cấp quyền.
  granted,

  /// Bị từ chối (vẫn có thể yêu cầu lại trên Android).
  denied,

  /// Bị từ chối vĩnh viễn (cần mở App Settings để bật lại).
  permanentlyDenied,

  /// Bị giới hạn bởi chính sách thiết bị (MDM / Parental Controls trên iOS).
  restricted;

  bool get isGranted => this == QrPermissionStatus.granted;

  bool get isPermanentlyDenied =>
      this == QrPermissionStatus.permanentlyDenied ||
      this == QrPermissionStatus.restricted;

  static QrPermissionStatus fromString(String? value) {
    switch (value) {
      case 'granted':
        return QrPermissionStatus.granted;
      case 'denied':
        return QrPermissionStatus.denied;
      case 'permanentlyDenied':
        return QrPermissionStatus.permanentlyDenied;
      case 'restricted':
        return QrPermissionStatus.restricted;
      case 'notDetermined':
      default:
        return QrPermissionStatus.notDetermined;
    }
  }
}

/// Cấu hình cho bộ quét mã QR.
class QrScannerConfig {
  /// Camera mặc định khi khởi động (sau hoặc trước).
  final QrCameraFacing cameraFacing;

  /// Bật đèn flash ngay khi khởi động camera (chỉ áp dụng cho camera sau).
  final bool enableFlash;

  /// Hiển thị lớp phủ tối (overlay) và khung ngắm.
  final bool showOverlay;

  /// Hiển thị hiệu ứng tia quét chạy dọc trong khung ngắm.
  final bool showAnimation;

  /// Kích thước cạnh của khung ngắm vuông (đơn vị: logical pixel).
  final double scanWindowSize;

  /// Chỉ nhận diện mã QR nằm bên trong vùng khung ngắm [scanWindowSize] (ROI).
  final bool restrictToScanWindow;

  /// Tự động gọi `start()` ngay khi PlatformView được gắn kết (attached).
  final bool autoStart;

  /// Khoảng thời gian tối thiểu giữa 2 lần phân tích frame ở tầng native.
  final Duration detectionTimeout;

  /// Khoảng thời gian bỏ qua nếu quét trúng cùng một nội dung QR liên tiếp.
  final Duration duplicateTimeout;

  const QrScannerConfig({
    this.cameraFacing = QrCameraFacing.back,
    this.enableFlash = false,
    this.showOverlay = true,
    this.showAnimation = true,
    this.scanWindowSize = 260,
    this.restrictToScanWindow = true,
    this.autoStart = true,
    this.detectionTimeout = const Duration(milliseconds: 250),
    this.duplicateTimeout = const Duration(seconds: 2),
  });

  QrScannerConfig copyWith({
    QrCameraFacing? cameraFacing,
    bool? enableFlash,
    bool? showOverlay,
    bool? showAnimation,
    double? scanWindowSize,
    bool? restrictToScanWindow,
    bool? autoStart,
    Duration? detectionTimeout,
    Duration? duplicateTimeout,
  }) {
    return QrScannerConfig(
      cameraFacing: cameraFacing ?? this.cameraFacing,
      enableFlash: enableFlash ?? this.enableFlash,
      showOverlay: showOverlay ?? this.showOverlay,
      showAnimation: showAnimation ?? this.showAnimation,
      scanWindowSize: scanWindowSize ?? this.scanWindowSize,
      restrictToScanWindow: restrictToScanWindow ?? this.restrictToScanWindow,
      autoStart: autoStart ?? this.autoStart,
      detectionTimeout: detectionTimeout ?? this.detectionTimeout,
      duplicateTimeout: duplicateTimeout ?? this.duplicateTimeout,
    );
  }
}
