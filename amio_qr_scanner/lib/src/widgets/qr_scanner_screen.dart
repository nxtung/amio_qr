import 'package:flutter/material.dart';

import '../controller/qr_scanner_controller.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scanner_config.dart';
import '../models/qr_scanner_state.dart';
import 'qr_scanner_view.dart';

/// Màn hình quét mã QR dựng sẵn (Default UI) có thể tái sử dụng ngay trong nhiều dự án.
///
/// Hỗ trợ:
/// - Tự động quản lý vòng đời Controller (hoặc truyền Controller từ ngoài vào).
/// - Thanh công cụ: Đóng, Tiêu đề, Bật/Tắt đèn Flash.
/// - Thanh tác vụ dưới: Đổi Camera trước/sau, Chọn ảnh QR từ thư viện (Gallery).
/// - Tự động hiển thị giao diện hướng dẫn cấp quyền hoặc mở Cài đặt khi quyền bị từ chối vĩnh viễn.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.controller,
    this.config = const QrScannerConfig(),
    this.title = 'Quét mã QR',
    this.hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    this.overlayColor = Colors.black54,
    this.scanLineColor = const Color(0xFFF26F25),
    this.showFlashButton = true,
    this.showSwitchCameraButton = true,
    this.showGalleryButton = true,
    this.galleryButtonLabel = 'Thư viện ảnh',
    this.popOnDetect = true,
    this.onDetect,
    this.onEmptyGalleryImage,
  });

  final QrScannerController? controller;
  final QrScannerConfig config;
  final String title;
  final String? hintText;
  final Color overlayColor;
  final Color scanLineColor;
  final bool showFlashButton;
  final bool showSwitchCameraButton;
  final bool showGalleryButton;
  final String galleryButtonLabel;
  final bool popOnDetect;
  final ValueChanged<QRScanResult>? onDetect;
  final VoidCallback? onEmptyGalleryImage;

  /// Hàm tiện ích mở màn hình quét QR và trả về chuỗi kết quả (hoặc `null` nếu đóng).
  static Future<String?> push(
    BuildContext context, {
    QrScannerConfig config = const QrScannerConfig(),
    String title = 'Quét mã QR',
    String? hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    Color overlayColor = Colors.black54,
    Color scanLineColor = const Color(0xFFF26F25),
    bool showFlashButton = true,
    bool showSwitchCameraButton = true,
    bool showGalleryButton = true,
  }) async {
    final result = await Navigator.of(context).push<QRScanResult>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          config: config,
          title: title,
          hintText: hintText,
          overlayColor: overlayColor,
          scanLineColor: scanLineColor,
          showFlashButton: showFlashButton,
          showSwitchCameraButton: showSwitchCameraButton,
          showGalleryButton: showGalleryButton,
        ),
      ),
    );
    return result?.value;
  }

  /// Hàm tiện ích mở màn hình quét QR và trả về đối tượng `QRScanResult` đầy đủ.
  static Future<QRScanResult?> pushForResult(
    BuildContext context, {
    QrScannerConfig config = const QrScannerConfig(),
    String title = 'Quét mã QR',
    String? hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    Color overlayColor = Colors.black54,
    Color scanLineColor = const Color(0xFFF26F25),
    bool showFlashButton = true,
    bool showSwitchCameraButton = true,
    bool showGalleryButton = true,
  }) {
    return Navigator.of(context).push<QRScanResult>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          config: config,
          title: title,
          hintText: hintText,
          overlayColor: overlayColor,
          scanLineColor: scanLineColor,
          showFlashButton: showFlashButton,
          showSwitchCameraButton: showSwitchCameraButton,
          showGalleryButton: showGalleryButton,
        ),
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final QrScannerController _controller;
  late final bool _ownsController;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? QrScannerController(config: widget.config);
  }

  void _handleDetect(QRScanResult result) {
    if (!mounted || _hasPopped) return;

    widget.onDetect?.call(result);

    if (widget.popOnDetect) {
      _hasPopped = true;
      _controller.pause();
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _handlePickGallery() async {
    final result = await _controller.pickAndScanImage(emitToStream: true);
    if (!mounted) return;
    if (result == null) {
      if (widget.onEmptyGalleryImage != null) {
        widget.onEmptyGalleryImage!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã QR trong ảnh đã chọn'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final state = _controller.state;

            return Stack(
              fit: StackFit.expand,
              children: [
                QrScannerView(
                  controller: _controller,
                  overlayColor: widget.overlayColor,
                  scanLineColor: widget.scanLineColor,
                  onDetect: _handleDetect,
                ),

                // Hiển thị thông báo hướng dẫn dưới khung ngắm
                if (widget.hintText != null &&
                    state.status == QrScannerStatus.running)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final windowSize = _controller.config.scanWindowSize
                          .clamp(100.0, constraints.biggest.shortestSide);
                      final topOffset =
                          (constraints.maxHeight + windowSize) / 2 + 24;

                      return Positioned(
                        top: topOffset.clamp(
                          0.0,
                          constraints.maxHeight - 100.0,
                        ),
                        left: 24,
                        right: 24,
                        child: Text(
                          widget.hintText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Giao diện khi quyền Camera bị từ chối
                if (state.status == QrScannerStatus.error &&
                    !state.hasPermission)
                  _PermissionDeniedView(
                    status: state.permissionStatus,
                    accentColor: widget.scanLineColor,
                    onRetry: _controller.start,
                    onOpenSettings: _controller.openAppSettings,
                  ),

                // Thanh tiêu đề trên cùng
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.showFlashButton)
                        IconButton(
                          onPressed: state.cameraFacing == QrCameraFacing.back
                              ? _controller.toggleFlash
                              : null,
                          icon: Icon(
                            state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: state.cameraFacing == QrCameraFacing.back
                                ? (state.isFlashOn
                                    ? widget.scanLineColor
                                    : Colors.white)
                                : Colors.white38,
                            size: 26,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Thanh điều khiển dưới cùng (Đổi camera & Chọn ảnh từ thư viện)
                if (widget.showSwitchCameraButton || widget.showGalleryButton)
                  Positioned(
                    bottom: 28,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.showGalleryButton)
                          _BottomActionButton(
                            icon: Icons.photo_library_outlined,
                            label: widget.galleryButtonLabel,
                            onTap: _handlePickGallery,
                          ),
                        if (widget.showSwitchCameraButton)
                          _BottomActionButton(
                            icon: Icons.cameraswitch_outlined,
                            label: 'Đổi camera',
                            onTap: _controller.switchCamera,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.status,
    required this.accentColor,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final QrPermissionStatus status;
  final Color accentColor;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isPermanent = status.isPermanentlyDenied;

    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                color: accentColor,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cần quyền truy cập Camera',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPermanent
                    ? 'Quyền Camera đã bị từ chối. Vui lòng mở Cài đặt ứng dụng để cấp quyền quét mã QR.'
                    : 'Ứng dụng cần quyền sử dụng Camera để quét mã QR.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: isPermanent ? onOpenSettings : onRetry,
                icon: Icon(isPermanent ? Icons.settings : Icons.camera_alt),
                label: Text(isPermanent ? 'Mở Cài đặt' : 'Cấp quyền Camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
