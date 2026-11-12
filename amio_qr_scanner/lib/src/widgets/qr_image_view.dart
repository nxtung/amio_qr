import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/qr_error_correction_level.dart';
import '../platform/qr_scanner_platform.dart';

/// Widget hiển thị mã QR được render từ link (URL) hoặc chuỗi bất kỳ.
///
/// Mã QR được tạo thông qua native layer (CameraX/ZXing trên Android, CoreImage trên iOS)
/// cho hiệu năng cao, độ sắc nét tuyệt đối và kích thước file tối ưu.
///
/// Ví dụ cơ bản:
/// ```dart
/// QrImageView(
///   data: 'https://amio.vn',
///   size: 200,
/// )
/// ```
///
/// Ví dụ có màu sắc và nhúng Logo ở giữa:
/// ```dart
/// QrImageView(
///   data: 'https://amio.vn/pay/order_123',
///   size: 240,
///   codeColor: const Color(0xFFF26F25),
///   errorCorrectionLevel: QrErrorCorrectionLevel.high,
///   embeddedImage: const AssetImage('assets/images/logo.png'),
///   embeddedImageSize: const Size(48, 48),
/// )
/// ```
class QrImageView extends StatefulWidget {
  const QrImageView({
    super.key,
    required this.data,
    this.size,
    this.width,
    this.height,
    this.resolution = 512,
    this.margin = 1,
    this.errorCorrectionLevel = QrErrorCorrectionLevel.medium,
    this.codeColor = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.padding,
    this.borderRadius,
    this.placeholder,
    this.errorBuilder,
    this.embeddedImage,
    this.embeddedImageSize = const Size(44, 44),
    this.embeddedImageBackgroundColor = Colors.white,
    this.embeddedImageBorderRadius,
    this.embeddedImagePadding = const EdgeInsets.all(4),
  });

  /// Dữ liệu link hoặc văn bản cần tạo mã QR.
  final String data;

  /// Kích thước hiển thị vuông (chiều rộng = chiều cao).
  final double? size;

  /// Chiều rộng hiển thị (nếu không set [size]).
  final double? width;

  /// Chiều cao hiển thị (nếu không set [size]).
  final double? height;

  /// Độ phân giải ảnh bitmap gốc được sinh từ native (mặc định 512px).
  final int resolution;

  /// Khoảng cách lề (quiet zone) tính theo module QR (mặc định 1).
  final int margin;

  /// Cấp độ sửa lỗi QR ([QrErrorCorrectionLevel.medium] mặc định).
  /// Khuyến nghị dùng [QrErrorCorrectionLevel.high] nếu có [embeddedImage].
  final QrErrorCorrectionLevel errorCorrectionLevel;

  /// Màu sắc của các module mã QR (mặc định đen).
  final Color codeColor;

  /// Màu nền của ảnh QR (mặc định trắng).
  final Color backgroundColor;

  /// Khoảng đệm bao quanh ảnh QR.
  final EdgeInsetsGeometry? padding;

  /// Bo góc cho toàn bộ khối QR widget.
  final BorderRadius? borderRadius;

  /// Widget hiển thị khi đang tạo ảnh QR.
  final WidgetBuilder? placeholder;

  /// Widget hiển thị khi việc tạo ảnh gặp lỗi.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Ảnh logo nhúng tại trung tâm của mã QR.
  final ImageProvider? embeddedImage;

  /// Kích thước hiển thị của logo trung tâm (mặc định 44x44).
  final Size embeddedImageSize;

  /// Màu nền phía sau logo trung tâm để module QR không bị chạm vào logo.
  final Color embeddedImageBackgroundColor;

  /// Bo góc cho khung nền của logo trung tâm.
  final BorderRadius? embeddedImageBorderRadius;

  /// Khoảng đệm giữa viền logo và hình ảnh logo.
  final EdgeInsetsGeometry embeddedImagePadding;

  // In-memory cache tĩnh nhằm tránh gọi lại PlatformChannel mỗi lần widget rebuild
  static final Map<String, Uint8List> _imageCache = <String, Uint8List>{};

  /// Xóa toàn bộ bộ nhớ cache ảnh QR đã sinh.
  static void clearCache() => _imageCache.clear();

  /// Tiện ích tĩnh: Tạo trực tiếp mảng bytes ảnh PNG của mã QR mà không cần gắn vào Widget.
  static Future<Uint8List> toImageBytes({
    required String data,
    int resolution = 512,
    int margin = 1,
    QrErrorCorrectionLevel errorCorrectionLevel = QrErrorCorrectionLevel.medium,
    Color codeColor = const Color(0xFF000000),
    Color backgroundColor = const Color(0xFFFFFFFF),
  }) {
    return QrScannerPlatform.instance.generateQrImage(
      data: data,
      width: resolution,
      height: resolution,
      margin: margin,
      errorCorrectionLevel: errorCorrectionLevel,
      codeColor: codeColor,
      backgroundColor: backgroundColor,
    );
  }

  @override
  State<QrImageView> createState() => _QrImageViewState();
}

class _QrImageViewState extends State<QrImageView> {
  Future<Uint8List>? _generationFuture;
  String? _currentCacheKey;

  String _buildCacheKey() {
    return '${widget.data}_${widget.resolution}_${widget.margin}_'
        '${widget.errorCorrectionLevel.value}_${widget.codeColor.toARGB32()}_${widget.backgroundColor.toARGB32()}';
  }

  @override
  void initState() {
    super.initState();
    _loadQrBytes();
  }

  @override
  void didUpdateWidget(covariant QrImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.resolution != widget.resolution ||
        oldWidget.margin != widget.margin ||
        oldWidget.errorCorrectionLevel != widget.errorCorrectionLevel ||
        oldWidget.codeColor != widget.codeColor ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      _loadQrBytes();
    }
  }

  void _loadQrBytes() {
    final key = _buildCacheKey();
    _currentCacheKey = key;

    final cached = QrImageView._imageCache[key];
    if (cached != null) {
      _generationFuture = Future.value(cached);
      return;
    }

    _generationFuture = QrScannerPlatform.instance
        .generateQrImage(
          data: widget.data,
          width: widget.resolution,
          height: widget.resolution,
          margin: widget.margin,
          errorCorrectionLevel: widget.errorCorrectionLevel,
          codeColor: widget.codeColor,
          backgroundColor: widget.backgroundColor,
        )
        .then((bytes) {
          QrImageView._imageCache[key] = bytes;
          return bytes;
        });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size ?? widget.width;
    final h = widget.size ?? widget.height;

    Widget content = FutureBuilder<Uint8List>(
      key: ValueKey(_currentCacheKey),
      future: _generationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder?.call(context) ??
              SizedBox(
                width: w,
                height: h,
                child: Center(
                  child: SizedBox(
                    width: (w != null ? w * 0.2 : 24.0).clamp(16.0, 36.0),
                    height: (h != null ? h * 0.2 : 24.0).clamp(16.0, 36.0),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error ?? Exception('Không tạo được mã QR'),
            );
          }
          return SizedBox(
            width: w,
            height: h,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.error,
                size: (w != null ? w * 0.25 : 32.0).clamp(20.0, 48.0),
              ),
            ),
          );
        }

        final bytes = snapshot.data!;
        Widget imageWidget = Image.memory(
          bytes,
          width: w,
          height: h,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        );

        if (widget.embeddedImage != null) {
          imageWidget = Stack(
            alignment: Alignment.center,
            children: [
              imageWidget,
              Container(
                width: widget.embeddedImageSize.width,
                height: widget.embeddedImageSize.height,
                padding: widget.embeddedImagePadding,
                decoration: BoxDecoration(
                  color: widget.embeddedImageBackgroundColor,
                  borderRadius:
                      widget.embeddedImageBorderRadius ??
                      BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      widget.embeddedImageBorderRadius != null
                          ? BorderRadius.circular(
                            (widget.embeddedImageBorderRadius!
                                        .topLeft
                                        .x -
                                    2)
                                .clamp(0.0, 100.0),
                          )
                          : BorderRadius.circular(6),
                  child: Image(
                    image: widget.embeddedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        }

        return imageWidget;
      },
    );

    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return content;
  }
}
