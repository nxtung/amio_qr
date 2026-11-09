## 1.0.0

* Phát hành phiên bản đầu tiên của `amio_qr_scanner` cho hệ sinh thái DGX / AMIO:
  * **Android**: CameraX (`1.4.2`) + Bundled Google ML Kit Barcode Scanning (`17.3.0`).
  * **iOS**: AVFoundation + Apple Vision Framework (`VNDetectBarcodesRequest`).
  * Hỗ trợ giới hạn vùng quét thực tế theo khung ngắm (ROI / Scan Window).
  * Chuẩn hóa hệ tọa độ Bounding Box (`0.0 - 1.0`) trên cả Android và iOS.
  * Hỗ trợ kiểm tra quyền chi tiết (`permanentlyDenied`) và mở App Settings (`openAppSettings()`).
  * Hỗ trợ quét mã QR từ file ảnh tĩnh và chọn ảnh từ Thư viện (Gallery).
  * Cung cấp sẵn `QrScannerView`, `QrScannerOverlay`, `QrScannerAnimation`, và màn hình dựng sẵn `QrScannerScreen`.
