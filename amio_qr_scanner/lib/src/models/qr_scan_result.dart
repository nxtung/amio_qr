import 'dart:ui';

/// Nguồn phát hiện mã QR (từ Camera trực tiếp hoặc từ ảnh tĩnh/thư viện).
enum QrScanSource {
  camera,
  image,
}

/// Kết quả nhận diện mã QR từ native engine.
class QRScanResult {
  /// Chuỗi nội dung của mã QR.
  final String value;

  /// Thời điểm nhận diện thành công.
  final DateTime timestamp;

  /// Tọa độ biên trái đã chuẩn hóa (0.0 - 1.0) theo khung nhìn preview.
  final double left;

  /// Tọa độ biên trên đã chuẩn hóa (0.0 - 1.0) theo khung nhìn preview.
  final double top;

  /// Chiều rộng vùng mã QR đã chuẩn hóa (0.0 - 1.0).
  final double width;

  /// Chiều cao vùng mã QR đã chuẩn hóa (0.0 - 1.0).
  final double height;

  /// Nguồn quét mã QR.
  final QrScanSource source;

  const QRScanResult({
    required this.value,
    required this.timestamp,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.source = QrScanSource.camera,
  });

  /// Khung bao (Bounding box) chuẩn hóa trong khoảng `0.0 - 1.0`.
  Rect get boundingBox => Rect.fromLTWH(left, top, width, height);

  /// Chuyển đổi tọa độ chuẩn hóa sang tọa độ thực tế trên màn hình [viewSize].
  Rect rectInView(Size viewSize) {
    return Rect.fromLTWH(
      left * viewSize.width,
      top * viewSize.height,
      width * viewSize.width,
      height * viewSize.height,
    );
  }

  factory QRScanResult.fromMap(Map<dynamic, dynamic> map) {
    final sourceStr = map['source']?.toString();
    final source =
        sourceStr == 'image' ? QrScanSource.image : QrScanSource.camera;

    return QRScanResult(
      value: map['value'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      left: ((map['left'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      top: ((map['top'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      width: ((map['width'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      height: ((map['height'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      source: source,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'value': value,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'source': source.name,
    };
  }

  @override
  String toString() =>
      'QRScanResult(value: $value, source: ${source.name}, box: [$left, $top, $width, $height])';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QRScanResult &&
        other.value == value &&
        other.timestamp == timestamp &&
        other.left == left &&
        other.top == top &&
        other.width == width &&
        other.height == height &&
        other.source == source;
  }

  @override
  int get hashCode =>
      Object.hash(value, timestamp, left, top, width, height, source);
}

/// Alias tiện lợi theo chuẩn đặt tên camelCase của Dart.
typedef QrScanResult = QRScanResult;
