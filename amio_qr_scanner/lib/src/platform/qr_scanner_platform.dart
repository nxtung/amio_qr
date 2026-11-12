import 'package:flutter/services.dart';

import '../models/qr_error_correction_level.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scanner_config.dart';

/// Giao tiếp tầng Platform dùng chung cho toàn plugin và các PlatformView.
class QrScannerPlatform {
  QrScannerPlatform._();

  static final QrScannerPlatform instance = QrScannerPlatform._();

  static const String viewType = 'vn.com.dgx/amio_qr_scanner/view';
  static const String pluginChannelName = 'vn.com.dgx/amio_qr_scanner/plugin';

  final MethodChannel _pluginChannel = const MethodChannel(pluginChannelName);

  static MethodChannel createViewMethodChannel(int viewId) {
    return MethodChannel('vn.com.dgx/amio_qr_scanner/methods_$viewId');
  }

  static EventChannel createViewEventChannel(int viewId) {
    return EventChannel('vn.com.dgx/amio_qr_scanner/events_$viewId');
  }

  /// Kiểm tra trạng thái quyền truy cập Camera hiện tại mà không bật hộp thoại xin quyền.
  Future<QrPermissionStatus> checkPermission() async {
    final status = await _pluginChannel.invokeMethod<String>('checkPermission');
    return QrPermissionStatus.fromString(status);
  }

  /// Yêu cầu quyền truy cập Camera và trả về trạng thái chi tiết (bao gồm `permanentlyDenied`).
  Future<QrPermissionStatus> requestPermission() async {
    final status =
        await _pluginChannel.invokeMethod<String>('requestPermission');
    return QrPermissionStatus.fromString(status);
  }

  /// Mở trang Cài đặt ứng dụng của hệ điều hành (App Settings) để người dùng cấp quyền thủ công.
  Future<bool> openAppSettings() async {
    final opened = await _pluginChannel.invokeMethod<bool>('openAppSettings');
    return opened ?? false;
  }

  /// Quét mã QR từ đường dẫn file ảnh tĩnh trên thiết bị.
  /// Trả về `QRScanResult` nếu tìm thấy mã QR, hoặc `null` nếu ảnh không chứa mã QR.
  Future<QRScanResult?> scanImagePath(String path) async {
    final map = await _pluginChannel.invokeMapMethod<dynamic, dynamic>(
      'scanImagePath',
      <String, dynamic>{'path': path},
    );
    if (map == null || map['value'] == null) return null;
    return QRScanResult.fromMap(map);
  }

  /// Mở bộ chọn ảnh hệ thống (System Photo Picker / Gallery) và giải mã QR từ ảnh được chọn.
  /// Trả về:
  /// - `QRScanResult` nếu tìm thấy mã QR trong ảnh đã chọn.
  /// - `null` nếu người dùng hủy chọn ảnh hoặc ảnh không có mã QR.
  Future<QRScanResult?> pickAndScanImage() async {
    final map = await _pluginChannel.invokeMapMethod<dynamic, dynamic>(
      'pickAndScanImage',
    );
    if (map == null || map['value'] == null) return null;
    return QRScanResult.fromMap(map);
  }

  /// Tạo ảnh mã QR định dạng PNG bytes (`Uint8List`) từ đường link URL hoặc văn bản bất kỳ.
  ///
  /// - [data]: Dữ liệu link URL hoặc chuỗi bất kỳ cần mã hóa vào QR.
  /// - [width], [height]: Kích thước pixel của ảnh tạo ra (mặc định 512x512).
  /// - [margin]: Khoảng cách lề (quiet zone) tính theo module QR (mặc định 1).
  /// - [errorCorrectionLevel]: Cấp độ sửa lỗi ([QrErrorCorrectionLevel.medium] mặc định).
  /// - [codeColor]: Màu của các module mã QR (mặc định đen).
  /// - [backgroundColor]: Màu nền ảnh QR (mặc định trắng).
  Future<Uint8List> generateQrImage({
    required String data,
    int width = 512,
    int height = 512,
    int margin = 1,
    QrErrorCorrectionLevel errorCorrectionLevel = QrErrorCorrectionLevel.medium,
    Color codeColor = const Color(0xFF000000),
    Color backgroundColor = const Color(0xFFFFFFFF),
  }) async {
    assert(data.isNotEmpty, 'QR data cannot be empty');
    final bytes = await _pluginChannel.invokeMethod<Uint8List>(
      'generateQrImage',
      <String, dynamic>{
        'data': data,
        'width': width,
        'height': height,
        'margin': margin,
        'errorCorrectionLevel': errorCorrectionLevel.value,
        'codeColor': codeColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
      },
    );

    if (bytes == null || bytes.isEmpty) {
      throw PlatformException(
        code: 'GENERATE_FAILED',
        message: 'Native plugin returned null or empty bytes for QR code',
      );
    }

    return bytes;
  }

  /// Lưu mảng bytes ảnh PNG vào Thư viện ảnh (Gallery/Photos) của máy bằng Native Engine.
  ///
  /// - [bytes]: Mảng bytes ảnh PNG.
  /// - [fileName]: Tên file tùy chọn (ví dụ: `my_qr.png`).
  Future<bool> saveImageToGallery({
    required Uint8List bytes,
    String? fileName,
  }) async {
    assert(bytes.isNotEmpty, 'Image bytes cannot be empty');
    final success = await _pluginChannel.invokeMethod<bool>(
      'saveImageToGallery',
      <String, dynamic>{
        'bytes': bytes,
        if (fileName != null) 'fileName': fileName,
      },
    );
    return success ?? false;
  }
}
