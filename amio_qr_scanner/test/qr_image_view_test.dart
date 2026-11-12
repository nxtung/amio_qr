import 'package:amio_qr_scanner/amio_qr_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pluginChannel = MethodChannel(QrScannerPlatform.pluginChannelName);
  // PNG giả lập 1x1 pixel trong suốt hợp lệ
  final fakePngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // Header PNG
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82,
  ]);

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    QrImageView.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, (call) async {
      calls.add(call);
      if (call.method == 'generateQrImage') {
        final data = call.arguments['data'] as String?;
        if (data == 'error_link') {
          throw PlatformException(code: 'GEN_FAIL', message: 'Failed');
        }
        return fakePngBytes;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, null);
  });

  group('QrScannerPlatform.generateQrImage', () {
    test('calls platform channel with correct arguments', () async {
      final bytes = await QrScannerPlatform.instance.generateQrImage(
        data: 'https://amio.vn',
        width: 300,
        height: 300,
        margin: 2,
        errorCorrectionLevel: QrErrorCorrectionLevel.high,
        codeColor: const Color(0xFFF26F25),
        backgroundColor: Colors.white,
      );

      expect(bytes, fakePngBytes);
      expect(calls.length, 1);
      final call = calls.first;
      expect(call.method, 'generateQrImage');
      expect(call.arguments['data'], 'https://amio.vn');
      expect(call.arguments['width'], 300);
      expect(call.arguments['height'], 300);
      expect(call.arguments['margin'], 2);
      expect(call.arguments['errorCorrectionLevel'], 'H');
    });

    test('static QrImageView.toImageBytes delegates to platform', () async {
      final bytes = await QrImageView.toImageBytes(
        data: 'https://amio.vn/test',
        resolution: 256,
      );

      expect(bytes, fakePngBytes);
      expect(calls.length, 1);
      expect(calls.first.arguments['data'], 'https://amio.vn/test');
      expect(calls.first.arguments['width'], 256);
    });
  });

  group('QrImageView widget', () {
    testWidgets('renders image once future completes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrImageView(
              data: 'https://amio.vn',
              size: 200,
            ),
          ),
        ),
      );

      // Ban đầu chờ future
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Sau khi xong hiển thị Image
      expect(find.byType(Image), findsOneWidget);
      expect(calls.length, 1);
    });

    testWidgets('uses in-memory cache to avoid redundant platform calls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrImageView(
              data: 'https://amio.vn/cache_test',
              size: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.length, 1);

      // Rebuild với widget tương đương cùng data
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrImageView(
              data: 'https://amio.vn/cache_test',
              size: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Không gọi lại platform channel vì đã có trong cache
      expect(calls.length, 1);
    });

    testWidgets('shows custom error widget when generation fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrImageView(
              data: 'error_link',
              size: 200,
              errorBuilder: (context, error) => const Text('Custom Error'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Error'), findsOneWidget);
    });
  });
}
