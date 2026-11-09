import 'package:flutter/material.dart';

import '../controller/qr_scanner_controller.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scanner_config.dart';
import '../models/qr_scanner_state.dart';
import 'qr_scanner_view.dart';

/// Bottom Sheet quét mã QR dựng sẵn, thuận tiện khi muốn mở nhanh khung quét
/// mà không cần chuyển sang một màn hình toàn cục mới.
class QrScannerBottomSheet extends StatefulWidget {
  const QrScannerBottomSheet({
    super.key,
    this.controller,
    this.config = const QrScannerConfig(scanWindowSize: 220),
    this.title = 'Quét mã QR',
    this.hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    this.heightFactor = 0.72,
    this.borderRadius = 24,
    this.overlayColor = Colors.black54,
    this.scanLineColor = const Color(0xFFF26F25),
    this.showFlashButton = true,
    this.showSwitchCameraButton = true,
    this.showGalleryButton = true,
    this.galleryButtonLabel = 'Thư viện ảnh',
    this.popOnDetect = true,
    this.onDetect,
  });

  final QrScannerController? controller;
  final QrScannerConfig config;
  final String title;
  final String? hintText;

  /// Tỉ lệ chiều cao của Bottom Sheet so với màn hình (0.4 - 0.95).
  final double heightFactor;
  final double borderRadius;
  final Color overlayColor;
  final Color scanLineColor;
  final bool showFlashButton;
  final bool showSwitchCameraButton;
  final bool showGalleryButton;
  final String galleryButtonLabel;
  final bool popOnDetect;
  final ValueChanged<QRScanResult>? onDetect;

  /// Mở Bottom Sheet quét mã QR và trả về chuỗi kết quả (hoặc `null` nếu đóng).
  static Future<String?> show(
    BuildContext context, {
    QrScannerConfig config = const QrScannerConfig(scanWindowSize: 220),
    String title = 'Quét mã QR',
    String? hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    double heightFactor = 0.72,
    double borderRadius = 24,
    Color overlayColor = Colors.black54,
    Color scanLineColor = const Color(0xFFF26F25),
    bool showFlashButton = true,
    bool showSwitchCameraButton = true,
    bool showGalleryButton = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final result = await showForResult(
      context,
      config: config,
      title: title,
      hintText: hintText,
      heightFactor: heightFactor,
      borderRadius: borderRadius,
      overlayColor: overlayColor,
      scanLineColor: scanLineColor,
      showFlashButton: showFlashButton,
      showSwitchCameraButton: showSwitchCameraButton,
      showGalleryButton: showGalleryButton,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    );
    return result?.value;
  }

  /// Mở Bottom Sheet quét mã QR và trả về đối tượng `QRScanResult` đầy đủ.
  static Future<QRScanResult?> showForResult(
    BuildContext context, {
    QrScannerConfig config = const QrScannerConfig(scanWindowSize: 220),
    String title = 'Quét mã QR',
    String? hintText = 'Đặt mã QR vào khung ngắm để quét tự động',
    double heightFactor = 0.72,
    double borderRadius = 24,
    Color overlayColor = Colors.black54,
    Color scanLineColor = const Color(0xFFF26F25),
    bool showFlashButton = true,
    bool showSwitchCameraButton = true,
    bool showGalleryButton = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<QRScanResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (_) => QrScannerBottomSheet(
        config: config,
        title: title,
        hintText: hintText,
        heightFactor: heightFactor,
        borderRadius: borderRadius,
        overlayColor: overlayColor,
        scanLineColor: scanLineColor,
        showFlashButton: showFlashButton,
        showSwitchCameraButton: showSwitchCameraButton,
        showGalleryButton: showGalleryButton,
      ),
    );
  }

  @override
  State<QrScannerBottomSheet> createState() => _QrScannerBottomSheetState();
}

class _QrScannerBottomSheetState extends State<QrScannerBottomSheet> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã QR trong ảnh đã chọn'),
          duration: Duration(seconds: 2),
        ),
      );
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * widget.heightFactor.clamp(0.4, 0.95);

    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.borderRadius),
        ),
        child: ColoredBox(
          color: Colors.black,
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

                  // Thanh kéo (Drag handle) + Header trên cùng
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.showFlashButton)
                                IconButton(
                                  onPressed:
                                      state.cameraFacing == QrCameraFacing.back
                                          ? _controller.toggleFlash
                                          : null,
                                  icon: Icon(
                                    state.isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color: state.cameraFacing ==
                                            QrCameraFacing.back
                                        ? (state.isFlashOn
                                            ? widget.scanLineColor
                                            : Colors.white)
                                        : Colors.white38,
                                  ),
                                )
                              else
                                const SizedBox(width: 48),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dòng hướng dẫn dưới khung ngắm
                  if (widget.hintText != null &&
                      state.status == QrScannerStatus.running)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final windowSize = _controller.config.scanWindowSize
                            .clamp(100.0, constraints.biggest.shortestSide);
                        final topOffset =
                            (constraints.maxHeight + windowSize) / 2 + 16;

                        return Positioned(
                          top: topOffset.clamp(
                            0.0,
                            constraints.maxHeight - 88.0,
                          ),
                          left: 24,
                          right: 24,
                          child: Text(
                            widget.hintText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
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

                  // Hiển thị thông báo khi thiếu quyền Camera
                  if (state.status == QrScannerStatus.error &&
                      !state.hasPermission)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.no_photography_outlined,
                              color: widget.scanLineColor,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.permissionStatus.isPermanentlyDenied
                                  ? 'Quyền Camera đã bị từ chối. Vui lòng mở Cài đặt để cấp quyền.'
                                  : 'Cần cấp quyền Camera để quét mã QR.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.scanLineColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  state.permissionStatus.isPermanentlyDenied
                                      ? _controller.openAppSettings
                                      : _controller.start,
                              icon: Icon(
                                state.permissionStatus.isPermanentlyDenied
                                    ? Icons.settings
                                    : Icons.camera_alt,
                              ),
                              label: Text(
                                state.permissionStatus.isPermanentlyDenied
                                    ? 'Mở Cài đặt'
                                    : 'Cấp quyền',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Thanh tác vụ dưới cùng
                  if (widget.showGalleryButton || widget.showSwitchCameraButton)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: SafeArea(
                        top: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (widget.showGalleryButton)
                              _SheetActionChip(
                                icon: Icons.photo_library_outlined,
                                label: widget.galleryButtonLabel,
                                onTap: _handlePickGallery,
                              ),
                            if (widget.showSwitchCameraButton)
                              _SheetActionChip(
                                icon: Icons.cameraswitch_outlined,
                                label: 'Đổi camera',
                                onTap: _controller.switchCamera,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetActionChip extends StatelessWidget {
  const _SheetActionChip({
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
