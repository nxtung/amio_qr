import 'package:amio_qr_scanner/amio_qr_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pluginChannel = MethodChannel(QrScannerPlatform.pluginChannelName);
  const viewChannel = MethodChannel('vn.com.dgx/amio_qr_scanner/methods_1');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, (call) async {
      switch (call.method) {
        case 'checkPermission':
          return 'granted';
        case 'requestPermission':
          return 'granted';
        case 'openAppSettings':
          return true;
        case 'scanImagePath':
          return <String, dynamic>{
            'type': 'result',
            'source': 'image',
            'value': '00020101021238570010A000000727',
            'timestamp': 1700000000000,
            'left': 0.2,
            'top': 0.2,
            'width': 0.6,
            'height': 0.6,
          };
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(viewChannel, (call) async {
      switch (call.method) {
        case 'requestPermission':
          return true;
        case 'start':
        case 'stop':
        case 'pause':
        case 'updateScanWindow':
        case 'resetDetection':
          return null;
        case 'toggleFlash':
          return true;
        case 'switchCamera':
          return 'front';
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pluginChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(viewChannel, null);
  });

  group('QRScanResult', () {
    test('parses from map and clamps normalized coordinates', () {
      final result = QRScanResult.fromMap(<String, dynamic>{
        'value': 'https://amio.vn',
        'timestamp': 1700000000000,
        'left': 0.15,
        'top': 0.25,
        'width': 0.5,
        'height': 0.5,
        'source': 'camera',
      });

      expect(result.value, 'https://amio.vn');
      expect(result.source, QrScanSource.camera);
      expect(result.boundingBox.left, 0.15);
      expect(result.boundingBox.top, 0.25);
      expect(result.boundingBox.width, 0.5);
      expect(result.boundingBox.height, 0.5);
    });
  });

  group('QrScannerController', () {
    test('starts automatically when attached if autoStart is true', () async {
      final controller = QrScannerController(
        config: const QrScannerConfig(autoStart: true),
      );

      controller.attach(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state.isAttached, isTrue);
      expect(controller.state.status, QrScannerStatus.running);
      expect(controller.state.hasPermission, isTrue);

      controller.dispose();
    });

    test('toggles flash and switches camera', () async {
      final controller = QrScannerController(
        config: const QrScannerConfig(autoStart: false),
      );

      controller.attach(1);
      await controller.start();
      expect(controller.state.status, QrScannerStatus.running);

      await controller.toggleFlash();
      expect(controller.state.isFlashOn, isTrue);

      await controller.switchCamera();
      expect(controller.state.cameraFacing, QrCameraFacing.front);
      expect(controller.state.isFlashOn, isFalse);

      await controller.pause();
      expect(controller.state.status, QrScannerStatus.paused);

      await controller.stop();
      expect(controller.state.status, QrScannerStatus.stopped);

      controller.dispose();
    });

    test('scans QR from image path and emits to stream', () async {
      final controller = QrScannerController(
        config: const QrScannerConfig(autoStart: false),
      );

      final emitted = <QRScanResult>[];
      final sub = controller.results.listen(emitted.add);

      final result = await controller.scanImagePath('/tmp/vietqr.png');
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull);
      expect(result!.value, '00020101021238570010A000000727');
      expect(result.source, QrScanSource.image);
      expect(emitted.length, 1);

      await sub.cancel();
      controller.dispose();
    });
  });
}
