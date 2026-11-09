# amio_qr_scanner

Thư viện Flutter Plugin quét mã QR Native độc lập dùng chung cho hệ sinh thái ứng dụng của DGX / AMIO (`amio`, `amiobiz`, `amio_ipad`, `ufid`, v.v.).

## Kiến trúc triển khai

- **Android**: Kotlin + CameraX (`1.4.2`) + Bundled Google ML Kit Barcode Scanning (`17.3.0` - hoạt động tức thì không cần chờ tải model).
- **iOS**: Swift + AVFoundation + Apple Vision Framework (`VNDetectBarcodesRequest`).
- **Flutter**: Dart Controller + PlatformView + MethodChannel + EventChannel (không truyền từng frame qua Flutter, không phụ thuộc `mobile_scanner`, `camera`, `image_picker` hay `permission_handler`).
- **Tính năng nổi bật**:
  - Chỉ nhận diện mã QR (`FORMAT_QR_CODE` / `.qr`), tối ưu tốc độ giải mã VietQR & QR thanh toán.
  - Hỗ trợ **giới hạn vùng nhận diện thực tế (ROI / Scan Window)** trên cả Android và iOS.
  - Chuẩn hóa hệ tọa độ Bounding Box (`0.0 - 1.0`) đồng nhất giữa Android và iOS.
  - Kiểm tra và yêu cầu quyền Camera chi tiết (`granted`, `denied`, `permanentlyDenied`, `restricted`) kèm hàm `openAppSettings()`.
  - Hỗ trợ **quét mã QR từ ảnh tĩnh / Thư viện ảnh (Gallery)** bằng System Picker native không cần cài thêm package ngoài.
  - Cung cấp sẵn `QrScannerScreen` (Default UI) và `QrScannerView` + `QrScannerOverlay` để tuỳ biến linh hoạt.

---

## 1. Tích hợp vào dự án

### Qua đường dẫn nội bộ (Local Path)

```yaml
dependencies:
  amio_qr_scanner:
    path: ../amio_qr/amio_qr_scanner
```

### Qua Git Repository

```yaml
dependencies:
  amio_qr_scanner:
    git:
      url: https://github.com/dgx-com-vn/amio_qr_scanner.git
      ref: main
```

### Cấu hình quyền trên iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần quyền truy cập Camera để quét mã QR.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Ứng dụng cần quyền truy cập Thư viện ảnh để chọn ảnh chứa mã QR.</string>
```

*(Trên Android, quyền `android.permission.CAMERA` đã được khai báo sẵn trong `AndroidManifest.xml` của plugin).*

---

## 2. Cách sử dụng nhanh

### Cách 1: Mở Bottom Sheet dựng sẵn `QrScannerBottomSheet` (không cần mở màn hình mới)

```dart
import 'package:amio_qr_scanner/amio_qr_scanner.dart';

final qrValue = await QrScannerBottomSheet.show(
  context,
  title: 'Quét mã QR',
  heightFactor: 0.72,
);

if (qrValue != null) {
  debugPrint('Nội dung QR: $qrValue');
}
```

### Cách 2: Dùng màn hình toàn cục dựng sẵn `QrScannerScreen`

```dart
import 'package:amio_qr_scanner/amio_qr_scanner.dart';

final qrValue = await QrScannerScreen.push(
  context,
  title: 'Quét mã QR',
  hintText: 'Đặt mã QR vào khung ngắm để thanh toán',
);

if (qrValue != null) {
  debugPrint('Nội dung QR: $qrValue');
}
```

### Cách 2: Tự xây dựng giao diện với `QrScannerView` và `QrScannerController`

```dart
final controller = QrScannerController(
  config: const QrScannerConfig(
    cameraFacing: QrCameraFacing.back,
    scanWindowSize: 260,
    restrictToScanWindow: true,
    showOverlay: true,
    showAnimation: true,
    detectionTimeout: Duration(milliseconds: 250),
    duplicateTimeout: Duration(seconds: 2),
  ),
);

// Trong Widget tree:
QrScannerView(
  controller: controller,
  onDetect: (QRScanResult result) {
    debugPrint('QR: ${result.value} (${result.source.name})');
  },
  onError: (String error) {
    debugPrint('Lỗi: $error');
  },
);
```

### Cách 3: Quét mã QR từ Thư viện ảnh hoặc File

```dart
// Mở bộ chọn ảnh hệ thống và giải mã QR:
final result = await controller.pickAndScanImage();

// Hoặc quét từ đường dẫn file ảnh có sẵn:
final fileResult = await controller.scanImagePath('/path/to/qr_image.png');
```

---

## 3. Danh sách Public API

| API | Mô tả |
| --- | --- |
| `checkPermission()` | Kiểm tra trạng thái quyền Camera hiện tại (`QrPermissionStatus`) |
| `requestPermission()` | Yêu cầu quyền Camera (`Future<bool>`) |
| `requestPermissionStatus()` | Yêu cầu quyền Camera, trả về chi tiết cả `permanentlyDenied` |
| `openAppSettings()` | Mở trang Cài đặt ứng dụng của hệ điều hành |
| `start()` | Khởi động camera và bắt đầu nhận diện |
| `stop()` | Dừng hẳn camera |
| `pause()` / `resume()` | Tạm dừng / Tiếp tục phiên quét |
| `toggleFlash()` | Bật / tắt đèn Flash |
| `switchCamera()` | Chuyển đổi camera trước / sau |
| `resetDetection()` | Xóa bộ nhớ chống trùng lặp mã QR |
| `scanImagePath(path)` | Quét mã QR từ đường dẫn file ảnh |
| `pickAndScanImage()` | Chọn ảnh từ Gallery và giải mã QR |
| `results` | `Stream<QRScanResult>` phát kết quả nhận diện |
| `state` | Trạng thái hiện tại (`QrScannerState`) |
