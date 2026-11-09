import 'package:amio_qr_scanner_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomePage displays demo actions', (WidgetTester tester) async {
    await tester.pumpWidget(const AmioQrExampleApp());

    expect(find.text('AMIO QR Scanner Demo'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu quét'), findsOneWidget);
  });
}
