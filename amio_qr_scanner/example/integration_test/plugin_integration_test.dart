import 'package:amio_qr_scanner/amio_qr_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QrScannerController initializes with default state', (
    WidgetTester tester,
  ) async {
    final controller = QrScannerController(
      config: const QrScannerConfig(autoStart: false),
    );
    expect(controller.state.status, QrScannerStatus.initial);
    controller.dispose();
  });
}
