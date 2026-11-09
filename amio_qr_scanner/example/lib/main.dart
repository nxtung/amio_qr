import 'package:amio_qr_scanner/amio_qr_scanner.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AmioQrExampleApp());
}

class AmioQrExampleApp extends StatelessWidget {
  const AmioQrExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMIO QR Scanner Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF26F25),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  QRScanResult? _lastResult;

  Future<void> _openDefaultBottomSheet() async {
    final result = await QrScannerBottomSheet.showForResult(
      context,
      title: 'Quét mã QR (Bottom Sheet)',
      heightFactor: 0.72,
    );
    if (result != null && mounted) {
      setState(() => _lastResult = result);
    }
  }

  Future<void> _openCustomBottomSheet() async {
    final result = await showModalBottomSheet<QRScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomScannerBottomSheet(),
    );
    if (result != null && mounted) {
      setState(() => _lastResult = result);
    }
  }

  Future<void> _openDefaultScanner() async {
    final result = await QrScannerScreen.pushForResult(
      context,
      title: 'Quét mã QR AMIO',
    );
    if (result != null && mounted) {
      setState(() => _lastResult = result);
    }
  }

  Future<void> _openCustomScanner() async {
    final result = await Navigator.of(context).push<QRScanResult>(
      MaterialPageRoute(builder: (_) => const CustomScannerPage()),
    );
    if (result != null && mounted) {
      setState(() => _lastResult = result);
    }
  }

  Future<void> _scanFromGalleryDirectly() async {
    final result = await QrScannerPlatform.instance.pickAndScanImage();
    if (!mounted) return;
    if (result != null) {
      setState(() => _lastResult = result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy mã QR hoặc đã hủy chọn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AMIO QR Scanner Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết quả quét gần nhất:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_lastResult == null)
                      const Text('Chưa có dữ liệu quét')
                    else ...[
                      SelectableText(
                        _lastResult!.value,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFF26F25),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Nguồn: ${_lastResult!.source.name}'),
                      Text('Thời gian: ${_lastResult!.timestamp}'),
                      Text(
                        'BoundingBox (normalized): '
                        'L=${_lastResult!.left.toStringAsFixed(2)}, '
                        'T=${_lastResult!.top.toStringAsFixed(2)}, '
                        'W=${_lastResult!.width.toStringAsFixed(2)}, '
                        'H=${_lastResult!.height.toStringAsFixed(2)}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openDefaultBottomSheet,
              icon: const Icon(Icons.vertical_align_top),
              label: const Text('Mở QrScannerBottomSheet dựng sẵn'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openCustomBottomSheet,
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Mở Custom Bottom Sheet (QrScannerView)'),
            ),
            const Divider(height: 32),
            FilledButton.tonalIcon(
              onPressed: _openDefaultScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Mở QrScannerScreen toàn màn hình'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openCustomScanner,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Mở Custom Full Screen (QrScannerView)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanFromGalleryDirectly,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Quét QR trực tiếp từ Thư viện ảnh'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ví dụ tự xây dựng một Modal Bottom Sheet tuỳ chỉnh chứa `QrScannerView`.
class CustomScannerBottomSheet extends StatefulWidget {
  const CustomScannerBottomSheet({super.key});

  @override
  State<CustomScannerBottomSheet> createState() =>
      _CustomScannerBottomSheetState();
}

class _CustomScannerBottomSheetState extends State<CustomScannerBottomSheet> {
  late final QrScannerController _controller;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = QrScannerController(
      config: const QrScannerConfig(
        cameraFacing: QrCameraFacing.back,
        scanWindowSize: 210,
        restrictToScanWindow: true,
        showOverlay: true,
        showAnimation: true,
      ),
    );
  }

  void _onDetect(QRScanResult result) {
    if (!mounted || _popped) return;
    _popped = true;
    _controller.pause();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.68;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final state = _controller.state;
                return Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    const Expanded(
                      child: Text(
                        'Quét QR thanh toán',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _controller.toggleFlash,
                      icon: Icon(
                        state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: state.isFlashOn
                            ? const Color(0xFFF26F25)
                            : Colors.black87,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: QrScannerView(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => _controller.pickAndScanImage(),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh từ thư viện'),
                  ),
                  TextButton.icon(
                    onPressed: _controller.switchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    label: const Text('Đổi camera'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomScannerPage extends StatefulWidget {
  const CustomScannerPage({super.key});

  @override
  State<CustomScannerPage> createState() => _CustomScannerPageState();
}

class _CustomScannerPageState extends State<CustomScannerPage> {
  late final QrScannerController _controller;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = QrScannerController(
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
  }

  void _onDetect(QRScanResult result) {
    if (!mounted || _popped) return;
    _popped = true;
    _controller.pause();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _controller.dispose();
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
              children: [
                QrScannerView(controller: _controller, onDetect: _onDetect),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Text(
                        'Custom QR Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: _controller.toggleFlash,
                        icon: Icon(
                          state.isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _controller.switchCamera,
                        icon: const Icon(
                          Icons.cameraswitch,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        onPressed: () => _controller.pickAndScanImage(),
                        icon: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 32,
                        ),
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
